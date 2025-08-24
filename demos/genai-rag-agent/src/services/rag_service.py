import os
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
import json

from src.services.knowledge_base import KnowledgeBaseService
from src.services.openfga_service import OpenFGAService, format_user, format_object

logger = logging.getLogger(__name__)

class RAGService:
    """Service for Retrieval Augmented Generation with OpenFGA authorization"""
    
    def __init__(self, knowledge_base_service: KnowledgeBaseService, openfga_service: OpenFGAService):
        self.kb_service = knowledge_base_service
        self.openfga_service = openfga_service
        
        # AI model configuration
        self.openai_api_key = os.getenv("OPENAI_API_KEY")
        self.default_model = os.getenv("DEFAULT_AI_MODEL", "gpt-3.5-turbo")
        self.max_context_tokens = int(os.getenv("MAX_CONTEXT_TOKENS", "4000"))
        
        # Initialize AI client (mock for demo)
        self.ai_client = None
        if self.openai_api_key:
            try:
                import openai
                self.ai_client = openai.AsyncOpenAI(api_key=self.openai_api_key)
                logger.info("OpenAI client initialized")
            except ImportError:
                logger.warning("OpenAI library not available, using mock responses")
        else:
            logger.warning("OpenAI API key not provided, using mock responses")
    
    async def process_query(
        self,
        user_id: str,
        session_id: str,
        question: str,
        context_filter: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Process a RAG query with authorization checks"""
        try:
            logger.info(f"Processing query for user {user_id} in session {session_id}")
            
            # Get session details to understand which knowledge bases to use
            session_kbs = await self._get_session_knowledge_bases(session_id)
            if not session_kbs:
                return {
                    "error": "No accessible knowledge bases found for session",
                    "answer": "I don't have access to any knowledge bases for this session."
                }
            
            # Filter knowledge bases based on user permissions
            authorized_kbs = []
            user_obj = format_user(user_id)
            
            for kb_id in session_kbs:
                kb_obj = format_object(kb_id, "knowledge_base")
                can_access = await self.openfga_service.check(user_obj, "viewer", kb_obj)
                if can_access:
                    authorized_kbs.append(kb_id)
                else:
                    logger.warning(f"User {user_id} denied access to knowledge base {kb_id}")
            
            if not authorized_kbs:
                return {
                    "error": "No authorized knowledge bases",
                    "answer": "You don't have permission to access any knowledge bases for this query."
                }
            
            # Retrieve relevant documents
            relevant_docs = await self.kb_service.search_documents(
                kb_ids=authorized_kbs,
                query=question,
                limit=5,
                metadata_filter=context_filter
            )
            
            # Filter documents based on individual permissions
            authorized_docs = []
            for doc_result in relevant_docs:
                doc = doc_result["document"]
                doc_obj = format_object(doc.id, "document")
                can_view = await self.openfga_service.check(user_obj, "viewer", doc_obj)
                if can_view:
                    authorized_docs.append(doc_result)
                else:
                    logger.warning(f"User {user_id} denied access to document {doc.id}")
            
            if not authorized_docs:
                return {
                    "error": "No authorized documents found",
                    "answer": "I couldn't find any documents you have permission to access that are relevant to your question."
                }
            
            # Generate response using retrieved context
            response = await self._generate_response(question, authorized_docs)
            
            # Audit the query
            await self._audit_query(user_id, session_id, question, response, authorized_docs)
            
            return response
            
        except Exception as e:
            logger.error(f"Failed to process query: {e}")
            return {
                "error": "Query processing failed",
                "answer": "I'm sorry, I encountered an error while processing your question."
            }
    
    async def _get_session_knowledge_bases(self, session_id: str) -> List[str]:
        """Get knowledge base IDs for a chat session"""
        # In production, retrieve from database
        # For demo, return default knowledge bases
        return ["kb_demo"]
    
    async def _generate_response(
        self,
        question: str,
        relevant_docs: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Generate AI response using retrieved documents"""
        try:
            # Prepare context from relevant documents
            context_parts = []
            sources = []
            
            for doc_result in relevant_docs:
                doc = doc_result["document"]
                excerpt = doc_result.get("excerpt", doc.content[:500])
                similarity = doc_result.get("similarity", 0.0)
                
                context_parts.append(f"Document: {doc.title}\nContent: {excerpt}")
                sources.append({
                    "id": doc.id,
                    "title": doc.title,
                    "similarity": similarity,
                    "metadata": doc.metadata
                })
            
            context = "\n\n".join(context_parts)
            
            # Create prompt for AI model
            prompt = self._create_rag_prompt(question, context)
            
            # Generate response
            if self.ai_client:
                answer = await self._call_openai(prompt)
            else:
                answer = await self._generate_mock_response(question, context)
            
            return {
                "answer": answer,
                "sources": sources,
                "context_used": len(context_parts),
                "model": self.default_model
            }
            
        except Exception as e:
            logger.error(f"Failed to generate response: {e}")
            return {
                "error": "Response generation failed",
                "answer": "I'm sorry, I couldn't generate a response at this time."
            }
    
    def _create_rag_prompt(self, question: str, context: str) -> str:
        """Create a prompt for RAG with context"""
        return f"""You are a helpful AI assistant with access to a knowledge base. Answer the user's question based on the provided context. If the context doesn't contain enough information to answer the question, say so clearly.

Context:
{context}

Question: {question}

Instructions:
- Base your answer primarily on the provided context
- If the context is insufficient, acknowledge this limitation
- Be concise but comprehensive
- Cite which documents your answer comes from when relevant
- Maintain a professional and helpful tone

Answer:"""
    
    async def _call_openai(self, prompt: str) -> str:
        """Call OpenAI API for response generation"""
        try:
            response = await self.ai_client.chat.completions.create(
                model=self.default_model,
                messages=[
                    {"role": "system", "content": "You are a helpful AI assistant that answers questions based on provided context."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=1000,
                temperature=0.1
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            logger.error(f"OpenAI API call failed: {e}")
            return "I'm sorry, I encountered an error while generating a response."
    
    async def _generate_mock_response(self, question: str, context: str) -> str:
        """Generate a mock response for demo purposes"""
        # Simple mock response based on question content
        question_lower = question.lower()
        
        if "openfga" in question_lower:
            return """Based on the provided context, OpenFGA is an open source Fine-Grained Authorization solution inspired by Google's Zanzibar paper. It provides a flexible, performant authorization system that supports relationship-based access control (ReBAC).

Key features include:
- Objects: Resources in your system (documents, files, repositories)
- Users: Entities that can perform actions  
- Relations: How users relate to objects (owner, editor, viewer)
- Tuples: Specific user-relation-object relationships

OpenFGA uses a configuration language to define authorization models and supports complex inheritance patterns. This makes it ideal for implementing fine-grained permissions in applications like this GenAI RAG system."""
        
        elif "rag" in question_lower or "retrieval" in question_lower:
            return """Retrieval Augmented Generation (RAG) combines the power of large language models with external knowledge retrieval. Based on the documents, best practices include:

1. Document chunking: Break documents into meaningful segments
2. Embedding quality: Use appropriate embedding models for your domain
3. Retrieval strategy: Implement semantic search with metadata filtering
4. Context management: Limit context size while maintaining relevance
5. Evaluation: Implement metrics for retrieval accuracy and generation quality

Security considerations are particularly important:
- Implement proper access controls on knowledge bases
- Filter retrieved content based on user permissions
- Audit and log all queries and responses

This system demonstrates these principles by using OpenFGA for authorization at every step."""
        
        elif "security" in question_lower or "permission" in question_lower:
            return """Based on the security documentation, when deploying AI models in production, security requires multiple layers:

Access Control:
- Role-based access to AI models (implemented here via OpenFGA)
- User permission restrictions for model usage
- API usage monitoring and rate limiting

Data Protection:
- Proper anonymization of training data
- Data retention policies implementation
- Encryption for data in transit and at rest

Model Governance:
- Version control for model deployments
- Audit trails for model decisions
- Regular security assessments and updates

This RAG system implements these principles by checking permissions at every level - from knowledge base access to individual document viewing."""
        
        else:
            return f"""I found some relevant information in the knowledge base that might help answer your question about: {question}

Based on the available context, I can provide insights related to OpenFGA authorization, RAG system best practices, and AI security guidelines. However, for a more specific answer, you might want to rephrase your question to focus on one of these areas.

The documents I have access to cover:
- OpenFGA concepts and implementation
- RAG architecture and best practices  
- AI model security guidelines

Would you like me to elaborate on any of these topics?"""
    
    async def _audit_query(
        self,
        user_id: str,
        session_id: str,
        question: str,
        response: Dict[str, Any],
        authorized_docs: List[Dict[str, Any]]
    ):
        """Audit the query for compliance and monitoring"""
        try:
            audit_entry = {
                "timestamp": datetime.now().isoformat(),
                "user_id": user_id,
                "session_id": session_id,
                "question": question,
                "response_generated": "answer" in response,
                "documents_accessed": [doc["document"].id for doc in authorized_docs],
                "knowledge_bases_used": list(set(doc["document"].knowledge_base_id for doc in authorized_docs)),
                "error": response.get("error"),
                "model_used": response.get("model", "mock")
            }
            
            # In production, store audit entries in a secure audit log
            logger.info(f"Query audit: {json.dumps(audit_entry, default=str)}")
            
        except Exception as e:
            logger.error(f"Failed to audit query: {e}")
    
    async def check_model_access(self, user_id: str, model_id: str) -> bool:
        """Check if user has access to a specific AI model"""
        user_obj = format_user(user_id)
        model_obj = format_object(model_id, "ai_model")
        return await self.openfga_service.check(user_obj, "user", model_obj)
    
    async def list_accessible_models(self, user_id: str) -> List[str]:
        """List AI models accessible to a user"""
        user_obj = format_user(user_id)
        return await self.openfga_service.list_objects(user_obj, "user", "ai_model")