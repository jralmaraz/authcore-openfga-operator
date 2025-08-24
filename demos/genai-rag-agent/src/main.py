import asyncio
import logging
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime
import uuid

from fastapi import FastAPI, HTTPException, Depends, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import uvicorn

from src.services.openfga_service import OpenFGAService, format_user, format_object
from src.services.rag_service import RAGService
from src.services.knowledge_base import KnowledgeBaseService
from src.middleware.auth import AuthMiddleware, get_current_user
from src.models.schemas import *

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="GenAI RAG Agent with OpenFGA Authorization",
    description="A Retrieval Augmented Generation agent with fine-grained authorization",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global services
openfga_service: Optional[OpenFGAService] = None
rag_service: Optional[RAGService] = None
knowledge_base_service: Optional[KnowledgeBaseService] = None

# Initialize services
@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    global openfga_service, rag_service, knowledge_base_service
    
    logger.info("🚀 Starting GenAI RAG Agent...")
    
    # Initialize OpenFGA service
    openfga_service = OpenFGAService()
    
    # Initialize knowledge base service
    knowledge_base_service = KnowledgeBaseService()
    
    # Initialize RAG service
    rag_service = RAGService(knowledge_base_service, openfga_service)
    
    logger.info("✅ All services initialized successfully")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("🛑 Shutting down GenAI RAG Agent...")

# Health check endpoint
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.now(),
        service="genai-rag-agent",
        version="1.0.0"
    )

# Knowledge Base endpoints
@app.post("/api/knowledge-bases", response_model=KnowledgeBaseResponse)
async def create_knowledge_base(
    request: CreateKnowledgeBaseRequest,
    current_user: UserInfo = Depends(get_current_user)
):
    """Create a new knowledge base"""
    try:
        # Check if user can create knowledge bases for their organization
        user_obj = format_user(current_user.user_id)
        org_obj = format_object(request.organization_id, "organization")
        
        can_create = await openfga_service.check(user_obj, "admin", org_obj)
        if not can_create:
            raise HTTPException(status_code=403, detail="Insufficient permissions to create knowledge base")
        
        # Create knowledge base
        kb_id = str(uuid.uuid4())
        kb = await knowledge_base_service.create_knowledge_base(
            kb_id, request.name, request.description, request.organization_id
        )
        
        # Set up OpenFGA relationships
        kb_obj = format_object(kb_id, "knowledge_base")
        await openfga_service.write_tuples([
            {"user": user_obj, "relation": "curator", "object": kb_obj},
            {"user": org_obj, "relation": "organization", "object": kb_obj}
        ])
        
        return KnowledgeBaseResponse(**kb.dict(), id=kb_id)
        
    except Exception as e:
        logger.error(f"Failed to create knowledge base: {e}")
        raise HTTPException(status_code=500, detail="Failed to create knowledge base")

@app.get("/api/knowledge-bases", response_model=List[KnowledgeBaseResponse])
async def list_knowledge_bases(
    current_user: UserInfo = Depends(get_current_user)
):
    """List accessible knowledge bases"""
    try:
        user_obj = format_user(current_user.user_id)
        
        # Get knowledge bases the user can view
        accessible_kbs = await openfga_service.list_objects(user_obj, "viewer", "knowledge_base")
        
        kb_list = []
        for kb_object in accessible_kbs:
            kb_id = kb_object.replace("knowledge_base:", "")
            kb = await knowledge_base_service.get_knowledge_base(kb_id)
            if kb:
                kb_list.append(KnowledgeBaseResponse(**kb.dict(), id=kb_id))
        
        return kb_list
        
    except Exception as e:
        logger.error(f"Failed to list knowledge bases: {e}")
        raise HTTPException(status_code=500, detail="Failed to list knowledge bases")

@app.post("/api/knowledge-bases/{kb_id}/documents", response_model=DocumentResponse)
async def upload_document(
    kb_id: str,
    request: UploadDocumentRequest,
    current_user: UserInfo = Depends(get_current_user)
):
    """Upload a document to a knowledge base"""
    try:
        # Check if user can contribute to this knowledge base
        user_obj = format_user(current_user.user_id)
        kb_obj = format_object(kb_id, "knowledge_base")
        
        can_contribute = await openfga_service.check(user_obj, "editor", kb_obj)
        if not can_contribute:
            raise HTTPException(status_code=403, detail="Insufficient permissions to upload documents")
        
        # Upload document
        doc_id = str(uuid.uuid4())
        doc = await knowledge_base_service.upload_document(
            doc_id, kb_id, request.title, request.content, request.metadata or {}
        )
        
        # Set up OpenFGA relationships for document
        doc_obj = format_object(doc_id, "document")
        kb = await knowledge_base_service.get_knowledge_base(kb_id)
        org_obj = format_object(kb.organization_id, "organization")
        
        await openfga_service.write_tuples([
            {"user": user_obj, "relation": "owner", "object": doc_obj},
            {"user": org_obj, "relation": "organization", "object": doc_obj}
        ])
        
        return DocumentResponse(**doc.dict(), id=doc_id)
        
    except Exception as e:
        logger.error(f"Failed to upload document: {e}")
        raise HTTPException(status_code=500, detail="Failed to upload document")

@app.get("/api/knowledge-bases/{kb_id}/documents", response_model=List[DocumentResponse])
async def list_documents(
    kb_id: str,
    current_user: UserInfo = Depends(get_current_user)
):
    """List documents in a knowledge base"""
    try:
        # Check if user can view this knowledge base
        user_obj = format_user(current_user.user_id)
        kb_obj = format_object(kb_id, "knowledge_base")
        
        can_view = await openfga_service.check(user_obj, "viewer", kb_obj)
        if not can_view:
            raise HTTPException(status_code=403, detail="Insufficient permissions to view knowledge base")
        
        # Get documents
        documents = await knowledge_base_service.list_documents(kb_id)
        
        # Filter documents based on individual permissions
        accessible_docs = []
        for doc in documents:
            doc_obj = format_object(doc.id, "document")
            can_view_doc = await openfga_service.check(user_obj, "viewer", doc_obj)
            if can_view_doc:
                accessible_docs.append(DocumentResponse(**doc.dict()))
        
        return accessible_docs
        
    except Exception as e:
        logger.error(f"Failed to list documents: {e}")
        raise HTTPException(status_code=500, detail="Failed to list documents")

# Chat and Query endpoints
@app.post("/api/chat/sessions", response_model=ChatSessionResponse)
async def create_chat_session(
    request: CreateChatSessionRequest,
    current_user: UserInfo = Depends(get_current_user)
):
    """Create a new chat session"""
    try:
        session_id = str(uuid.uuid4())
        
        # Create chat session
        session = ChatSession(
            id=session_id,
            name=request.name,
            organization_id=request.organization_id,
            knowledge_base_ids=request.knowledge_base_ids,
            model_id=request.model_id,
            created_at=datetime.now(),
            created_by=current_user.user_id
        )
        
        # Verify user has access to specified knowledge bases
        user_obj = format_user(current_user.user_id)
        for kb_id in request.knowledge_base_ids:
            kb_obj = format_object(kb_id, "knowledge_base")
            can_access = await openfga_service.check(user_obj, "viewer", kb_obj)
            if not can_access:
                raise HTTPException(
                    status_code=403, 
                    detail=f"Insufficient permissions to access knowledge base {kb_id}"
                )
        
        # Check model access
        model_obj = format_object(request.model_id, "ai_model")
        can_use_model = await openfga_service.check(user_obj, "user", model_obj)
        if not can_use_model:
            raise HTTPException(status_code=403, detail="Insufficient permissions to use this AI model")
        
        # Set up OpenFGA relationships
        session_obj = format_object(session_id, "chat_session")
        org_obj = format_object(request.organization_id, "organization")
        
        await openfga_service.write_tuples([
            {"user": user_obj, "relation": "owner", "object": session_obj},
            {"user": org_obj, "relation": "organization", "object": session_obj}
        ])
        
        # Store session (in production, use proper database)
        # For demo, we'll use in-memory storage
        
        return ChatSessionResponse(**session.dict())
        
    except Exception as e:
        logger.error(f"Failed to create chat session: {e}")
        raise HTTPException(status_code=500, detail="Failed to create chat session")

@app.post("/api/chat/sessions/{session_id}/query", response_model=QueryResponse)
async def submit_query(
    session_id: str,
    request: SubmitQueryRequest,
    background_tasks: BackgroundTasks,
    current_user: UserInfo = Depends(get_current_user)
):
    """Submit a query to the RAG system"""
    try:
        # Check if user can access this chat session
        user_obj = format_user(current_user.user_id)
        session_obj = format_object(session_id, "chat_session")
        
        can_access = await openfga_service.check(user_obj, "viewer", session_obj)
        if not can_access:
            raise HTTPException(status_code=403, detail="Insufficient permissions to access chat session")
        
        # Create query
        query_id = str(uuid.uuid4())
        query = Query(
            id=query_id,
            session_id=session_id,
            user_id=current_user.user_id,
            question=request.question,
            context_filter=request.context_filter,
            created_at=datetime.now(),
            status="processing"
        )
        
        # Set up OpenFGA relationships for query
        query_obj = format_object(query_id, "query")
        await openfga_service.write_tuples([
            {"user": user_obj, "relation": "requester", "object": query_obj},
            {"user": session_obj, "relation": "chat_session", "object": query_obj}
        ])
        
        # Process query in background
        background_tasks.add_task(
            process_query_background, 
            query_id, 
            session_id, 
            request.question,
            request.context_filter,
            current_user.user_id
        )
        
        return QueryResponse(**query.dict())
        
    except Exception as e:
        logger.error(f"Failed to submit query: {e}")
        raise HTTPException(status_code=500, detail="Failed to submit query")

@app.get("/api/chat/sessions/{session_id}/queries/{query_id}", response_model=QueryResponse)
async def get_query_result(
    session_id: str,
    query_id: str,
    current_user: UserInfo = Depends(get_current_user)
):
    """Get the result of a query"""
    try:
        # Check if user can view this query
        user_obj = format_user(current_user.user_id)
        query_obj = format_object(query_id, "query")
        
        can_view = await openfga_service.check(user_obj, "viewer", query_obj)
        if not can_view:
            raise HTTPException(status_code=403, detail="Insufficient permissions to view query")
        
        # Get query result (from storage)
        # For demo, return mock response
        query = Query(
            id=query_id,
            session_id=session_id,
            user_id=current_user.user_id,
            question="Sample question",
            answer="Sample answer from RAG system",
            sources=["doc1", "doc2"],
            created_at=datetime.now(),
            completed_at=datetime.now(),
            status="completed"
        )
        
        return QueryResponse(**query.dict())
        
    except Exception as e:
        logger.error(f"Failed to get query result: {e}")
        raise HTTPException(status_code=500, detail="Failed to get query result")

# User and permissions endpoints
@app.get("/api/users/me", response_model=UserInfoResponse)
async def get_current_user_info(current_user: UserInfo = Depends(get_current_user)):
    """Get current user information and permissions"""
    try:
        user_obj = format_user(current_user.user_id)
        
        # Get user permissions
        permissions = {}
        
        # Check organization permissions
        for org_id in ["demo-org"]:  # In production, get from user's organizations
            org_obj = format_object(org_id, "organization")
            permissions[f"org:{org_id}"] = {
                "admin": await openfga_service.check(user_obj, "admin", org_obj),
                "member": await openfga_service.check(user_obj, "member", org_obj),
                "viewer": await openfga_service.check(user_obj, "viewer", org_obj)
            }
        
        # Get accessible resources
        accessible_kbs = await openfga_service.list_objects(user_obj, "viewer", "knowledge_base")
        accessible_models = await openfga_service.list_objects(user_obj, "viewer", "ai_model")
        accessible_sessions = await openfga_service.list_objects(user_obj, "viewer", "chat_session")
        
        return UserInfoResponse(
            user_id=current_user.user_id,
            email=current_user.email,
            role=current_user.role,
            permissions=permissions,
            accessible_resources={
                "knowledge_bases": len(accessible_kbs),
                "ai_models": len(accessible_models),
                "chat_sessions": len(accessible_sessions)
            }
        )
        
    except Exception as e:
        logger.error(f"Failed to get user info: {e}")
        raise HTTPException(status_code=500, detail="Failed to get user info")

# Background task for processing queries
async def process_query_background(
    query_id: str, 
    session_id: str, 
    question: str,
    context_filter: Optional[Dict[str, Any]],
    user_id: str
):
    """Process a query in the background using RAG"""
    try:
        logger.info(f"Processing query {query_id} for user {user_id}")
        
        # Use RAG service to process the query
        result = await rag_service.process_query(
            user_id=user_id,
            session_id=session_id,
            question=question,
            context_filter=context_filter
        )
        
        # Update query with result (store in database)
        logger.info(f"Query {query_id} processed successfully")
        
    except Exception as e:
        logger.error(f"Failed to process query {query_id}: {e}")

# Run the application
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )