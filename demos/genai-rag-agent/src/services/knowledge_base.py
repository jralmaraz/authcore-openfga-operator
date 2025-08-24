import os
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
import json
import asyncio
from pathlib import Path

# For demo purposes, we'll use simple in-memory storage
# In production, use a proper vector database like Chroma, Pinecone, or Weaviate

from src.models.schemas import KnowledgeBase, Document

logger = logging.getLogger(__name__)

class KnowledgeBaseService:
    """Service for managing knowledge bases and documents"""
    
    def __init__(self):
        # In-memory storage for demo
        self.knowledge_bases: Dict[str, KnowledgeBase] = {}
        self.documents: Dict[str, Document] = {}
        self.document_vectors: Dict[str, List[float]] = {}  # Document ID -> embeddings
        
        # Initialize with demo data
        asyncio.create_task(self._initialize_demo_data())
    
    async def _initialize_demo_data(self):
        """Initialize with sample data for demo"""
        try:
            # Create demo knowledge base
            demo_kb = await self.create_knowledge_base(
                "kb_demo",
                "Demo Knowledge Base",
                "Sample knowledge base for GenAI demonstrations",
                "demo-org"
            )
            
            # Add sample documents
            sample_docs = [
                {
                    "title": "OpenFGA Introduction",
                    "content": """OpenFGA is an open source Fine-Grained Authorization solution inspired by Google's Zanzibar paper. 
                    It provides a flexible, performant authorization system that supports relationship-based access control (ReBAC).
                    
                    Key concepts:
                    - Objects: Resources in your system (documents, files, repositories)
                    - Users: Entities that can perform actions
                    - Relations: How users relate to objects (owner, editor, viewer)
                    - Tuples: Specific user-relation-object relationships
                    
                    OpenFGA uses a configuration language to define authorization models and supports complex inheritance patterns."""
                },
                {
                    "title": "RAG Architecture Best Practices",
                    "content": """Retrieval Augmented Generation (RAG) combines the power of large language models with external knowledge retrieval.
                    
                    Best practices for RAG systems:
                    1. Document chunking: Break documents into meaningful segments
                    2. Embedding quality: Use appropriate embedding models for your domain
                    3. Retrieval strategy: Implement semantic search with metadata filtering
                    4. Context management: Limit context size while maintaining relevance
                    5. Evaluation: Implement metrics for retrieval accuracy and generation quality
                    
                    Security considerations:
                    - Implement proper access controls on knowledge bases
                    - Filter retrieved content based on user permissions
                    - Audit and log all queries and responses"""
                },
                {
                    "title": "AI Model Security Guidelines",
                    "content": """When deploying AI models in production, security is paramount:
                    
                    Access Control:
                    - Implement role-based access to AI models
                    - Restrict model usage based on user permissions
                    - Monitor and rate-limit API usage
                    
                    Data Protection:
                    - Ensure training data is properly anonymized
                    - Implement data retention policies
                    - Use encryption for data in transit and at rest
                    
                    Model Governance:
                    - Version control for model deployments
                    - Audit trails for model decisions
                    - Regular security assessments and updates"""
                }
            ]
            
            for i, doc_data in enumerate(sample_docs):
                await self.upload_document(
                    f"doc_demo_{i}",
                    "kb_demo",
                    doc_data["title"],
                    doc_data["content"],
                    {"category": "demo", "index": i}
                )
            
            logger.info("Demo knowledge base initialized with sample documents")
            
        except Exception as e:
            logger.error(f"Failed to initialize demo data: {e}")
    
    async def create_knowledge_base(
        self,
        kb_id: str,
        name: str,
        description: str,
        organization_id: str
    ) -> KnowledgeBase:
        """Create a new knowledge base"""
        kb = KnowledgeBase(
            name=name,
            description=description,
            organization_id=organization_id,
            created_at=datetime.now(),
            document_count=0
        )
        
        self.knowledge_bases[kb_id] = kb
        logger.info(f"Created knowledge base: {kb_id}")
        return kb
    
    async def get_knowledge_base(self, kb_id: str) -> Optional[KnowledgeBase]:
        """Get a knowledge base by ID"""
        return self.knowledge_bases.get(kb_id)
    
    async def list_knowledge_bases(self, organization_id: Optional[str] = None) -> List[KnowledgeBase]:
        """List knowledge bases, optionally filtered by organization"""
        kbs = list(self.knowledge_bases.values())
        if organization_id:
            kbs = [kb for kb in kbs if kb.organization_id == organization_id]
        return kbs
    
    async def upload_document(
        self,
        doc_id: str,
        kb_id: str,
        title: str,
        content: str,
        metadata: Dict[str, Any],
        created_by: str = "system"
    ) -> Document:
        """Upload a document to a knowledge base"""
        if kb_id not in self.knowledge_bases:
            raise ValueError(f"Knowledge base {kb_id} not found")
        
        doc = Document(
            id=doc_id,
            title=title,
            content=content,
            knowledge_base_id=kb_id,
            created_at=datetime.now(),
            created_by=created_by,
            metadata=metadata
        )
        
        self.documents[doc_id] = doc
        
        # Update knowledge base document count
        self.knowledge_bases[kb_id].document_count += 1
        
        # Generate embeddings (mock for demo)
        self.document_vectors[doc_id] = await self._generate_embeddings(content)
        
        logger.info(f"Uploaded document: {doc_id} to knowledge base: {kb_id}")
        return doc
    
    async def get_document(self, doc_id: str) -> Optional[Document]:
        """Get a document by ID"""
        return self.documents.get(doc_id)
    
    async def list_documents(self, kb_id: str) -> List[Document]:
        """List documents in a knowledge base"""
        return [doc for doc in self.documents.values() if doc.knowledge_base_id == kb_id]
    
    async def search_documents(
        self,
        kb_ids: List[str],
        query: str,
        limit: int = 10,
        metadata_filter: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """Search documents using semantic similarity"""
        try:
            # Generate query embedding (mock for demo)
            query_vector = await self._generate_embeddings(query)
            
            # Get candidate documents from specified knowledge bases
            candidates = []
            for doc in self.documents.values():
                if doc.knowledge_base_id in kb_ids:
                    # Apply metadata filter if specified
                    if metadata_filter:
                        if not self._matches_filter(doc.metadata, metadata_filter):
                            continue
                    
                    # Calculate similarity (mock implementation)
                    similarity = await self._calculate_similarity(
                        query_vector, 
                        self.document_vectors.get(doc.id, [])
                    )
                    
                    candidates.append({
                        "document": doc,
                        "similarity": similarity,
                        "excerpt": self._extract_excerpt(doc.content, query)
                    })
            
            # Sort by similarity and return top results
            candidates.sort(key=lambda x: x["similarity"], reverse=True)
            return candidates[:limit]
            
        except Exception as e:
            logger.error(f"Search failed: {e}")
            return []
    
    async def _generate_embeddings(self, text: str) -> List[float]:
        """Generate embeddings for text (mock implementation)"""
        # In production, use a proper embedding model like:
        # - sentence-transformers
        # - OpenAI embeddings
        # - Cohere embeddings
        
        # Mock embedding based on text hash
        import hashlib
        hash_val = int(hashlib.md5(text.encode()).hexdigest(), 16)
        return [(hash_val >> i) % 1000 / 1000.0 for i in range(0, 384, 8)]
    
    async def _calculate_similarity(self, vec1: List[float], vec2: List[float]) -> float:
        """Calculate cosine similarity between vectors (mock implementation)"""
        if not vec1 or not vec2 or len(vec1) != len(vec2):
            return 0.0
        
        # Simple dot product similarity for demo
        similarity = sum(a * b for a, b in zip(vec1, vec2))
        return max(0.0, min(1.0, similarity / len(vec1)))
    
    def _matches_filter(self, metadata: Dict[str, Any], filter_dict: Dict[str, Any]) -> bool:
        """Check if document metadata matches filter"""
        for key, value in filter_dict.items():
            if key not in metadata or metadata[key] != value:
                return False
        return True
    
    def _extract_excerpt(self, content: str, query: str, max_length: int = 200) -> str:
        """Extract relevant excerpt from document content"""
        query_words = query.lower().split()
        content_lower = content.lower()
        
        # Find the position of the first query word
        best_pos = 0
        for word in query_words:
            pos = content_lower.find(word)
            if pos != -1:
                best_pos = max(0, pos - 50)  # Start a bit before the match
                break
        
        # Extract excerpt
        excerpt = content[best_pos:best_pos + max_length]
        if len(content) > best_pos + max_length:
            excerpt += "..."
        
        return excerpt.strip()