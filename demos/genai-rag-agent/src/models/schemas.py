from typing import List, Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field
import uuid

# Request/Response Models
class CreateKnowledgeBaseRequest(BaseModel):
    name: str = Field(..., description="Name of the knowledge base")
    description: str = Field("", description="Description of the knowledge base")
    organization_id: str = Field(..., description="Organization ID that owns this knowledge base")

class UploadDocumentRequest(BaseModel):
    title: str = Field(..., description="Document title")
    content: str = Field(..., description="Document content")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata")

class CreateChatSessionRequest(BaseModel):
    name: str = Field(..., description="Session name")
    organization_id: str = Field(..., description="Organization ID")
    knowledge_base_ids: List[str] = Field(..., description="Knowledge base IDs to use")
    model_id: str = Field(..., description="AI model ID to use")

class SubmitQueryRequest(BaseModel):
    question: str = Field(..., description="The question to ask")
    context_filter: Optional[Dict[str, Any]] = Field(None, description="Context filtering options")

# Response Models
class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    service: str
    version: str

class KnowledgeBaseResponse(BaseModel):
    id: str
    name: str
    description: str
    organization_id: str
    created_at: datetime
    document_count: int = 0

class DocumentResponse(BaseModel):
    id: str
    title: str
    knowledge_base_id: str
    created_at: datetime
    created_by: str
    metadata: Dict[str, Any] = {}

class ChatSessionResponse(BaseModel):
    id: str
    name: str
    organization_id: str
    knowledge_base_ids: List[str]
    model_id: str
    created_at: datetime
    created_by: str

class QueryResponse(BaseModel):
    id: str
    session_id: str
    user_id: str
    question: str
    answer: Optional[str] = None
    sources: List[str] = []
    created_at: datetime
    completed_at: Optional[datetime] = None
    status: str = "processing"

class UserInfoResponse(BaseModel):
    user_id: str
    email: str
    role: str
    permissions: Dict[str, Any]
    accessible_resources: Dict[str, int]

# Core Data Models
class UserInfo(BaseModel):
    user_id: str
    email: str
    role: str = "user"

class KnowledgeBase(BaseModel):
    name: str
    description: str
    organization_id: str
    created_at: datetime
    document_count: int = 0

class Document(BaseModel):
    id: str
    title: str
    content: str
    knowledge_base_id: str
    created_at: datetime
    created_by: str
    metadata: Dict[str, Any] = {}

class ChatSession(BaseModel):
    id: str
    name: str
    organization_id: str
    knowledge_base_ids: List[str]
    model_id: str
    created_at: datetime
    created_by: str

class Query(BaseModel):
    id: str
    session_id: str
    user_id: str
    question: str
    answer: Optional[str] = None
    sources: List[str] = []
    context_filter: Optional[Dict[str, Any]] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
    status: str = "processing"

class AIModel(BaseModel):
    id: str
    name: str
    description: str
    model_type: str  # "openai", "anthropic", "huggingface", etc.
    organization_id: str
    configuration: Dict[str, Any] = {}
    created_at: datetime