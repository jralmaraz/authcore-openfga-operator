# GenAI RAG Application OpenFGA Configuration Example

This file shows how to set up and use the GenAI RAG Application OpenFGA authorization model.

## 1. Store Creation

First, create an OpenFGA store and import the authorization model:

```bash
# Create store
curl -X POST http://localhost:8080/stores \
  -H "Content-Type: application/json" \
  -d '{
    "name": "genai-rag-demo"
  }'

# Import authorization model (save the model_id from response)
curl -X POST http://localhost:8080/stores/{store_id}/authorization-models \
  -H "Content-Type: application/json" \
  -d @authorization-model.json
```

## 2. Write Relationship Tuples

Add the relationship tuples to establish permissions:

```bash
# Organization relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "user:diana",
          "relation": "admin",
          "object": "organization:org1"
        },
        {
          "user": "user:alice",
          "relation": "member",
          "object": "organization:org1"
        },
        {
          "user": "user:bob",
          "relation": "member",
          "object": "organization:org1"
        },
        {
          "user": "user:charlie",
          "relation": "member",
          "object": "organization:org1"
        }
      ]
    }
  }'

# Knowledge base relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "organization:org1",
          "relation": "parent_org",
          "object": "knowledge_base:kb1"
        },
        {
          "user": "user:alice",
          "relation": "curator",
          "object": "knowledge_base:kb1"
        },
        {
          "user": "user:bob",
          "relation": "contributor",
          "object": "knowledge_base:kb1"
        },
        {
          "user": "user:charlie",
          "relation": "reader",
          "object": "knowledge_base:kb1"
        }
      ]
    }
  }'

# Document relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "knowledge_base:kb1",
          "relation": "parent_kb",
          "object": "document:doc1"
        },
        {
          "user": "user:alice",
          "relation": "owner",
          "object": "document:doc1"
        },
        {
          "user": "user:bob",
          "relation": "editor",
          "object": "document:doc1"
        },
        {
          "user": "user:charlie",
          "relation": "viewer",
          "object": "document:doc1"
        },
        {
          "user": "knowledge_base:kb1",
          "relation": "parent_kb",
          "object": "document:doc2"
        },
        {
          "user": "user:alice",
          "relation": "owner",
          "object": "document:doc2"
        },
        {
          "user": "user:bob",
          "relation": "viewer",
          "object": "document:doc2"
        },
        {
          "user": "knowledge_base:kb1",
          "relation": "parent_kb",
          "object": "document:doc3"
        },
        {
          "user": "user:diana",
          "relation": "owner",
          "object": "document:doc3"
        }
      ]
    }
  }'

# AI Model relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "organization:org1",
          "relation": "parent_org",
          "object": "ai_model:model1"
        },
        {
          "user": "user:eve",
          "relation": "operator",
          "object": "ai_model:model1"
        },
        {
          "user": "user:alice",
          "relation": "user",
          "object": "ai_model:model1"
        },
        {
          "user": "user:bob",
          "relation": "user",
          "object": "ai_model:model1"
        }
      ]
    }
  }'

# RAG Session relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "knowledge_base:kb1",
          "relation": "parent_kb",
          "object": "rag_session:session1"
        },
        {
          "user": "ai_model:model1",
          "relation": "parent_model",
          "object": "rag_session:session1"
        },
        {
          "user": "user:bob",
          "relation": "owner",
          "object": "rag_session:session1"
        },
        {
          "user": "user:charlie",
          "relation": "participant",
          "object": "rag_session:session1"
        }
      ]
    }
  }'

# RAG Query relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "rag_session:session1",
          "relation": "parent_session",
          "object": "rag_query:query1"
        },
        {
          "user": "user:bob",
          "relation": "initiated_by",
          "object": "rag_query:query1"
        },
        {
          "user": "document:doc1",
          "relation": "queried_documents",
          "object": "rag_query:query1"
        }
      ]
    }
  }'
```

## 3. Check Authorization

Now you can check permissions using the Check API:

```bash
# Check if Alice (curator) can view knowledge base
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:alice",
      "relation": "can_view",
      "object": "knowledge_base:kb1"
    }
  }'
# Expected: {"allowed": true}

# Check if Bob (contributor) can contribute to knowledge base
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:bob",
      "relation": "can_contribute",
      "object": "knowledge_base:kb1"
    }
  }'
# Expected: {"allowed": true}

# Check if Charlie (reader) can edit document
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:charlie",
      "relation": "can_edit",
      "object": "document:doc1"
    }
  }'
# Expected: {"allowed": false}

# Check if Bob can use document in RAG
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:bob",
      "relation": "can_use_in_rag",
      "object": "document:doc1"
    }
  }'
# Expected: {"allowed": true}

# Check if Eve (model operator) can configure AI model
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:eve",
      "relation": "can_configure",
      "object": "ai_model:model1"
    }
  }'
# Expected: {"allowed": true}

# Check if Bob can access query results
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:bob",
      "relation": "can_access_results",
      "object": "rag_query:query1"
    }
  }'
# Expected: {"allowed": true}

# Check if unauthorized user can view confidential document
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:bob",
      "relation": "can_view",
      "object": "document:doc3"
    }
  }'
# Expected: {"allowed": false}
```

## 4. Content Filtering Example

Check what documents a user can access for RAG:

```bash
# Find all documents Bob can use in RAG
curl -X POST http://localhost:8080/stores/{store_id}/list-objects \
  -H "Content-Type: application/json" \
  -d '{
    "user": "user:bob",
    "relation": "can_use_in_rag",
    "type": "document"
  }'
# Expected: ["document:doc1", "document:doc2"] (but not doc3)

# Find all knowledge bases Charlie can view
curl -X POST http://localhost:8080/stores/{store_id}/list-objects \
  -H "Content-Type: application/json" \
  -d '{
    "user": "user:charlie",
    "relation": "can_view",
    "type": "knowledge_base"
  }'
```

## 5. RAG Application Integration

Here's how you might integrate this into a RAG application:

```python
import requests
import json

class RAGAuthorizationService:
    def __init__(self, openfga_url, store_id):
        self.openfga_url = openfga_url
        self.store_id = store_id
    
    def check_permission(self, user, relation, object_type, object_id):
        """Check if user has permission for a specific action"""
        response = requests.post(
            f"{self.openfga_url}/stores/{self.store_id}/check",
            json={
                "tuple_key": {
                    "user": f"user:{user}",
                    "relation": relation,
                    "object": f"{object_type}:{object_id}"
                }
            }
        )
        return response.json().get("allowed", False)
    
    def get_accessible_documents(self, user):
        """Get all documents user can access for RAG"""
        response = requests.post(
            f"{self.openfga_url}/stores/{self.store_id}/list-objects",
            json={
                "user": f"user:{user}",
                "relation": "can_use_in_rag",
                "type": "document"
            }
        )
        return response.json().get("objects", [])
    
    def filter_rag_response(self, user, query_id, response_text):
        """Filter RAG response based on user permissions"""
        if self.check_permission(user, "can_access_results", "rag_query", query_id):
            return response_text
        else:
            return "Access denied: Insufficient permissions to view query results"

# Usage in RAG application
auth_service = RAGAuthorizationService("http://localhost:8080", "your-store-id")

def process_rag_query(user_id, query_text, session_id):
    # Check if user can query in this session
    if not auth_service.check_permission(user_id, "can_query", "rag_session", session_id):
        return {"error": "Unauthorized to query in this session"}
    
    # Get documents user can access
    accessible_docs = auth_service.get_accessible_documents(user_id)
    
    # Filter documents for RAG retrieval
    filtered_docs = filter_documents_by_accessibility(accessible_docs, query_text)
    
    # Generate response using only accessible documents
    rag_response = generate_rag_response(query_text, filtered_docs)
    
    # Store query and check final access
    query_id = store_rag_query(user_id, session_id, query_text, filtered_docs, rag_response)
    
    # Return filtered response
    return {
        "response": auth_service.filter_rag_response(user_id, query_id, rag_response),
        "query_id": query_id
    }

def create_rag_session(user_id, kb_id, model_id, session_name):
    # Check if user can view KB and use model
    if not auth_service.check_permission(user_id, "can_view", "knowledge_base", kb_id):
        return {"error": "Cannot access knowledge base"}
    
    if not auth_service.check_permission(user_id, "can_use", "ai_model", model_id):
        return {"error": "Cannot use AI model"}
    
    # Create session
    session_id = create_session(user_id, kb_id, model_id, session_name)
    return {"session_id": session_id}
```

## 6. Document Management Integration

```javascript
// Document management API with authorization
class DocumentManager {
    constructor(authService) {
        this.auth = authService;
    }
    
    async getDocument(userId, docId) {
        const canView = await this.auth.checkPermission(
            userId, 'can_view', 'document', docId
        );
        
        if (!canView) {
            throw new Error('Insufficient permissions to view document');
        }
        
        return await this.fetchDocument(docId);
    }
    
    async updateDocument(userId, docId, content) {
        const canEdit = await this.auth.checkPermission(
            userId, 'can_edit', 'document', docId
        );
        
        if (!canEdit) {
            throw new Error('Insufficient permissions to edit document');
        }
        
        return await this.saveDocument(docId, content);
    }
    
    async deleteDocument(userId, docId) {
        const canDelete = await this.auth.checkPermission(
            userId, 'can_delete', 'document', docId
        );
        
        if (!canDelete) {
            throw new Error('Insufficient permissions to delete document');
        }
        
        return await this.removeDocument(docId);
    }
    
    async getUserDocuments(userId) {
        const accessible = await this.auth.getAccessibleObjects(
            userId, 'can_view', 'document'
        );
        
        return await this.fetchDocuments(accessible);
    }
}
```

## 7. Knowledge Base Curation

```bash
# Example: Add a new contributor to knowledge base
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "user:new_contributor",
          "relation": "contributor",
          "object": "knowledge_base:kb1"
        }
      ]
    }
  }'

# Example: Grant document editing permission
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "user:editor",
          "relation": "editor",
          "object": "document:doc1"
        }
      ]
    }
  }'

# Example: Remove permissions
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "deletes": {
      "tuple_keys": [
        {
          "user": "user:old_contributor",
          "relation": "contributor",
          "object": "knowledge_base:kb1"
        }
      ]
    }
  }'
```

This configuration enables sophisticated content filtering for RAG applications, ensuring users only see information they're authorized to access while maintaining the flexibility needed for collaborative knowledge management.