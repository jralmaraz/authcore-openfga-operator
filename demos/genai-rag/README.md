# GenAI RAG Agent Demo

This demo showcases how to implement fine-grained authorization for a Generative AI Retrieval-Augmented Generation (RAG) application using OpenFGA. The demo includes a comprehensive authorization model that supports knowledge base management, document-level permissions, AI model access control, and session-based RAG interactions.

## Authorization Model

The OpenFGA authorization model defines the following entity types and relationships:

### Entity Types

1. **Organization**
   - Relations: `admin`, `member`
   - Provides organizational context for all resources

2. **Knowledge Base**
   - Relations: `parent_org`, `curator`, `contributor`, `reader`, `can_view`, `can_contribute`, `can_curate`, `can_admin`
   - Three-tier role system for knowledge management
   - Inherits organization-level permissions

3. **Document**
   - Relations: `parent_kb`, `owner`, `editor`, `viewer`, `can_view`, `can_edit`, `can_delete`, `can_use_in_rag`
   - Fine-grained document access control
   - Content filtering for RAG responses based on permissions

4. **AI Model**
   - Relations: `parent_org`, `operator`, `user`, `can_use`, `can_configure`, `can_admin`
   - Controlled access to AI models and configurations
   - Operator-level permissions for model management

5. **RAG Session**
   - Relations: `parent_kb`, `parent_model`, `owner`, `participant`, `can_view`, `can_query`, `can_access_documents`, `can_admin`
   - Session-based access control for RAG interactions
   - Intersection permissions for document access during RAG

6. **RAG Query**
   - Relations: `parent_session`, `queried_documents`, `initiated_by`, `can_view`, `can_access_results`
   - Query-level permissions with document filtering
   - Results access based on document permissions

### Key Features

- **Role-Based Knowledge Management**: Curator, contributor, and reader roles with hierarchical permissions
- **Document-Level Security**: Individual document permissions with inheritance from knowledge base
- **Content Filtering**: RAG responses filtered based on user's document access permissions
- **AI Model Access Control**: Separate permissions for using and configuring AI models
- **Session-Based RAG**: Controlled RAG sessions with participant management
- **Intersection Permissions**: Users must have both session access AND document permissions to see RAG results
- **Organizational Context**: All resources inherit base permissions from organization membership

## Demo Scenarios

The demo includes the following test scenarios:

### Knowledge Base Access Control
- Curators can view, contribute, and curate content
- Contributors can view and contribute but not curate
- Readers can only view content
- Organization members have basic view access

### Document-Level Permissions
- Document owners can view, edit, and delete
- Editors can view and edit but not delete
- Viewers can only view documents
- KB contributors can edit documents in their knowledge base
- KB curators can delete any document in their knowledge base

### AI Model Management
- Model operators can use, configure, and admin models
- Model users can only use models
- Organization members have basic usage rights
- Configuration requires operator or admin permissions

### RAG Session Security
- Session owners can manage sessions and query
- Participants can view sessions and make queries
- Document access during RAG requires both session permissions AND document permissions
- Results are filtered based on user's document access rights

### Content Filtering
- RAG responses are filtered based on document-level permissions
- Users without document access see "Access denied" messages
- Confidential documents are excluded from unauthorized RAG sessions

## Usage

```rust
use crate::demos::genai_rag::GenAIRAGDemo;

// Create demo instance
let demo = GenAIRAGDemo::new();

// Check authorization
let request = AuthorizationRequest {
    user: "user:alice".to_string(),
    relation: "can_view".to_string(),
    object: "knowledge_base:kb1".to_string(),
};
let response = demo.check_authorization(&request);
assert!(response.allowed);

// Get filtered documents for a user
let accessible_docs = demo.get_documents_for_user("bob");
println!("User can access {} documents", accessible_docs.len());

// Get filtered RAG response
let response = demo.get_filtered_rag_response("query1", "bob");
match response {
    Some(text) => println!("RAG response: {}", text),
    None => println!("Query not found"),
}

// Get OpenFGA tuples
let tuples = demo.get_tuples();
println!("Total tuples: {}", tuples.len());
```

## Testing

Run the GenAI RAG demo tests:

```bash
cargo test genai_rag_demo
```

The tests cover:
- Knowledge base role enforcement
- Document-level permissions
- AI model access control
- RAG session management
- Query result filtering
- Content filtering for confidential documents
- Organization-level inheritance
- Intersection permissions

## Content Filtering Example

The demo includes an example of how content filtering works in RAG responses:

```rust
// User with proper access gets full response
let response = demo.get_filtered_rag_response("query1", "bob");
// Returns: "To authenticate with the API, you need to use OAuth 2.0..."

// User without document access gets filtered response
let response = demo.get_filtered_rag_response("query1", "unauthorized_user");
// Returns: "Access denied: Insufficient permissions to view query results"
```

## OpenFGA Model File

The complete OpenFGA authorization model is available in `authorization-model.json` and can be imported into an OpenFGA server for production use. The model supports complex intersection and union relationships to implement proper content filtering for RAG applications.