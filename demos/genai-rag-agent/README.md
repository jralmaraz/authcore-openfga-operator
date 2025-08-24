# GenAI RAG Agent Demo

A sophisticated Retrieval Augmented Generation (RAG) agent that demonstrates fine-grained authorization using OpenFGA. This demo showcases how to build secure AI applications with proper access controls for knowledge bases, documents, AI models, and user interactions.

## 🎯 Overview

This demo implements a complete RAG system with OpenFGA authorization, inspired by the Auth0 blog post on [GenAI, LangChain.js, and FGA](https://auth0.com/blog/genai-langchain-js-fga). It demonstrates:

- **Document-level authorization**: Fine-grained access control for knowledge base documents
- **AI model permissions**: Role-based access to different AI models  
- **Session management**: Secure chat sessions with participant controls
- **Context-aware responses**: RAG responses filtered by user permissions
- **Audit logging**: Comprehensive logging of all AI interactions

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GenAI RAG Agent Architecture                  │
├─────────────────────────────────────────────────────────────────┤
│  FastAPI Application (Python)                                   │
│  ├── Knowledge Base Management  ├── Chat Session Management     │
│  ├── Document Upload/Search     ├── Query Processing           │
│  └── User/Permission Management └── AI Model Integration       │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     OpenFGA Authorization                       │
│  ├── GenAI Authorization Model                                  │
│  ├── Document-level Permissions                                 │
│  ├── AI Model Access Controls                                   │
│  └── Session-based Authorization                                │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RAG Processing Pipeline                       │
│  ├── Document Retrieval (with auth filtering)                   │
│  ├── Context Building (authorized content only)                 │
│  ├── AI Response Generation                                     │
│  └── Audit Logging                                             │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Features

### Core RAG Capabilities
- **Knowledge Base Management**: Create and organize document collections
- **Document Upload**: Add documents with metadata and automatic embedding
- **Semantic Search**: Find relevant documents using vector similarity
- **AI Response Generation**: Generate contextual responses using retrieved documents
- **Multiple AI Models**: Support for OpenAI, Anthropic, and other models

### Authorization Features
The demo implements a comprehensive authorization model with these entities:

- **Organization**: Top-level organizational boundary
- **Knowledge Base**: Collections of documents with curator/contributor/reader roles
- **Document**: Individual documents with owner/editor/viewer permissions
- **AI Model**: AI models with usage permissions
- **Chat Session**: Conversation sessions with owner/participant access
- **Query**: Individual queries linked to sessions

### Security Roles
- **User**: Basic users with limited access
- **Contributor**: Can add documents to knowledge bases
- **Curator**: Can manage knowledge bases and their contents
- **Admin**: Full organizational access and user management

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- OpenFGA instance running (via OpenFGA Operator)
- kubectl access to Kubernetes cluster
- Optional: OpenAI API key for real AI responses

### Local Development

1. **Clone and setup:**
   ```bash
   cd demos/genai-rag-agent
   pip install -r requirements.txt
   cp .env.example .env
   ```

2. **Configure environment:**
   Edit `.env` file with your configuration:
   ```env
   OPENFGA_API_URL=http://localhost:8080
   OPENFGA_STORE_ID=your-store-id
   OPENFGA_AUTH_MODEL_ID=your-model-id
   OPENAI_API_KEY=your-openai-key  # Optional
   ```

3. **Initialize demo data:**
   ```bash
   python setup.py
   ```
   This creates the OpenFGA store, uploads the authorization model, and sets up demo users.

4. **Start the application:**
   ```bash
   python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
   ```

5. **Access the API:**
   - API Documentation: http://localhost:8000/docs
   - Health Check: http://localhost:8000/health

### Kubernetes Deployment

1. **Deploy OpenFGA instance:**
   ```bash
   kubectl apply -f ../../examples/basic-openfga.yaml
   ```

2. **Build and deploy the GenAI RAG agent:**
   ```bash
   # Build Docker image
   docker build -t genai-rag-agent:latest .
   
   # Deploy to Kubernetes
   kubectl apply -f k8s/
   ```

3. **Setup demo data in Kubernetes:**
   ```bash
   kubectl exec -it deployment/genai-rag-agent -- python setup.py
   ```

## 📚 API Documentation

### Authentication
All API requests require user identification headers:
```bash
-H "x-user-id: alice"
-H "x-user-role: user"
-H "x-user-email: alice@example.com"
```

Or use Bearer token authentication:
```bash
-H "Authorization: Bearer demo_alice"
```

### Demo Users
The setup script creates these demo users:
- `alice` (user) - Can access demo knowledge base and basic AI models
- `bob` (user) - Limited access to resources
- `charlie` (curator) - Can manage knowledge bases and contribute content
- `diana` (admin) - Full organizational access and advanced AI models

### API Endpoints

#### Knowledge Base Management
```bash
# List accessible knowledge bases
curl -H "x-user-id: alice" http://localhost:8000/api/knowledge-bases

# Create knowledge base (curator/admin only)
curl -X POST http://localhost:8000/api/knowledge-bases \
  -H "x-user-id: charlie" \
  -H "Content-Type: application/json" \
  -d '{"name": "My Knowledge Base", "description": "Personal documents", "organization_id": "demo-org"}'

# Upload document (requires editor access to KB)
curl -X POST http://localhost:8000/api/knowledge-bases/kb_demo/documents \
  -H "x-user-id: charlie" \
  -H "Content-Type: application/json" \
  -d '{"title": "AI Ethics Guide", "content": "This document covers ethical considerations...", "metadata": {"category": "ethics"}}'

# List documents in knowledge base
curl -H "x-user-id: alice" http://localhost:8000/api/knowledge-bases/kb_demo/documents
```

#### Chat Session Management
```bash
# Create chat session
curl -X POST http://localhost:8000/api/chat/sessions \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "AI Research Chat",
    "organization_id": "demo-org",
    "knowledge_base_ids": ["kb_demo"],
    "model_id": "gpt-3.5-turbo"
  }'

# Submit query to chat session
curl -X POST http://localhost:8000/api/chat/sessions/SESSION_ID/query \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What is OpenFGA and how does it work with AI systems?",
    "context_filter": {"category": "security"}
  }'

# Get query result
curl -H "x-user-id: alice" http://localhost:8000/api/chat/sessions/SESSION_ID/queries/QUERY_ID
```

#### User Information
```bash
# Get current user info and permissions
curl -H "x-user-id: alice" http://localhost:8000/api/users/me

# Expected response:
{
  "user_id": "alice",
  "email": "alice@example.com",
  "role": "user",
  "permissions": {
    "org:demo-org": {
      "admin": false,
      "member": true,
      "viewer": true
    }
  },
  "accessible_resources": {
    "knowledge_bases": 1,
    "ai_models": 2,
    "chat_sessions": 1
  }
}
```

## 🔐 Authorization Examples

### Scenario 1: Knowledge Base Access
```bash
# Alice can view demo knowledge base (has reader access)
curl -H "x-user-id: alice" http://localhost:8000/api/knowledge-bases/kb_demo/documents
# ✅ Returns accessible documents

# Bob cannot access private knowledge base
curl -H "x-user-id: bob" http://localhost:8000/api/knowledge-bases/kb_private/documents
# ❌ 403 Forbidden

# Charlie can manage knowledge bases (curator role)
curl -X POST http://localhost:8000/api/knowledge-bases/kb_demo/documents \
  -H "x-user-id: charlie" \
  -H "Content-Type: application/json" \
  -d '{"title": "New Document", "content": "Content here"}'
# ✅ Document uploaded successfully
```

### Scenario 2: AI Model Permissions
```bash
# Alice can use basic models
curl -X POST http://localhost:8000/api/chat/sessions \
  -H "x-user-id: alice" \
  -d '{"model_id": "gpt-3.5-turbo", ...}'
# ✅ Session created

# Alice cannot use premium models
curl -X POST http://localhost:8000/api/chat/sessions \
  -H "x-user-id: alice" \
  -d '{"model_id": "gpt-4", ...}'
# ❌ 403 Forbidden - Insufficient permissions to use this AI model

# Diana (admin) can use any model
curl -X POST http://localhost:8000/api/chat/sessions \
  -H "x-user-id: diana" \
  -d '{"model_id": "claude-2", ...}'
# ✅ Session created with premium model
```

### Scenario 3: Document-Level Security
```bash
# Query with document filtering
curl -X POST http://localhost:8000/api/chat/sessions/SESSION_ID/query \
  -H "x-user-id: alice" \
  -d '{"question": "What are the security best practices?"}'

# Response will only include documents Alice has permission to view:
{
  "answer": "Based on accessible documents...",
  "sources": [
    {"id": "doc_demo_0", "title": "OpenFGA Introduction", "similarity": 0.85},
    {"id": "doc_demo_2", "title": "AI Model Security Guidelines", "similarity": 0.78}
  ],
  "context_used": 2
}
```

## 🧪 Testing Authorization

The demo includes comprehensive authorization testing:

```bash
# Test user permissions
curl -H "x-user-id: alice" http://localhost:8000/api/users/me

# Test knowledge base access
curl -H "x-user-id: alice" http://localhost:8000/api/knowledge-bases

# Test document filtering in queries
curl -X POST http://localhost:8000/api/chat/sessions/SESSION_ID/query \
  -H "x-user-id: alice" \
  -d '{"question": "Tell me about confidential information"}'
# Should only return documents Alice has access to
```

## 🔧 Configuration

### Environment Variables
- `HOST`: Server host (default: 0.0.0.0)
- `PORT`: Server port (default: 8000)
- `OPENFGA_API_URL`: OpenFGA server URL
- `OPENFGA_STORE_ID`: OpenFGA store identifier
- `OPENFGA_AUTH_MODEL_ID`: Authorization model identifier
- `OPENAI_API_KEY`: OpenAI API key (optional, enables real AI responses)
- `DEFAULT_AI_MODEL`: Default AI model to use
- `DEMO_MODE`: Enable demo mode with mock responses

### OpenFGA Authorization Model
The model is defined in `models/genai-authorization-model.json`. Key relationships:

- **Organization**: `admin`, `member`, `viewer`
- **Knowledge Base**: `curator`, `contributor`, `reader`, `viewer`, `editor`
- **Document**: `owner`, `editor`, `viewer` (inherits from organization)
- **AI Model**: `admin`, `user`, `viewer` (inherits from organization)
- **Chat Session**: `owner`, `participant`, `viewer`
- **Query**: `requester`, `viewer` (inherits from chat session)

## 🤖 AI Integration

### Supported Models
- **OpenAI**: GPT-3.5-turbo, GPT-4 (requires API key)
- **Mock Responses**: Demo responses when no API key provided
- **Extensible**: Easy to add support for other AI providers

### RAG Pipeline
1. **Query Authorization**: Check user can access chat session
2. **Knowledge Base Filtering**: Only search authorized knowledge bases
3. **Document Retrieval**: Semantic search with permission filtering
4. **Context Building**: Combine authorized documents into context
5. **AI Generation**: Generate response using filtered context
6. **Audit Logging**: Log all interactions for compliance

## 🐳 Docker Support

```bash
# Build image
docker build -t genai-rag-agent:latest .

# Run container
docker run -p 8000:8000 \
  -e OPENFGA_API_URL=http://host.docker.internal:8080 \
  -e OPENFGA_STORE_ID=your-store-id \
  -e OPENFGA_AUTH_MODEL_ID=your-model-id \
  -e OPENAI_API_KEY=your-openai-key \
  genai-rag-agent:latest
```

## 🚀 Production Considerations

### Security
- Implement proper JWT authentication
- Use HTTPS in production
- Enable rate limiting and input validation
- Implement comprehensive audit logging
- Use secrets management for API keys

### Scalability
- Use proper vector database (Chroma, Pinecone, Weaviate)
- Implement caching for embeddings and OpenFGA responses
- Add connection pooling and async processing
- Use horizontal pod autoscaling

### AI Integration
- Support multiple AI providers (OpenAI, Anthropic, Azure OpenAI)
- Implement content filtering and safety checks
- Add response caching and optimization
- Monitor AI usage and costs

## 📊 Monitoring and Observability

The application provides comprehensive logging and metrics:

- **Request/Response Logging**: All API interactions
- **Authorization Auditing**: Permission checks and decisions
- **AI Query Auditing**: Questions, responses, and accessed documents
- **Error Tracking**: Detailed error logging with context
- **Performance Metrics**: Response times and resource usage

## 🤝 Contributing

This demo is part of the OpenFGA Operator project. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

## 📄 License

This demo is licensed under the Apache 2.0 License - see the [LICENSE](../../LICENSE) file for details.

## 🆘 Support

For issues and questions:
- Check the [main documentation](../../README.md)
- Review the FastAPI docs at `/docs` when running
- Open an issue in the repository
- Join the OpenFGA community discussions

## 🔗 References

- [OpenFGA Documentation](https://openfga.dev/docs/)
- [OpenFGA Modeling Guide](https://openfga.dev/docs/modeling)
- [Auth0 GenAI Blog Post](https://auth0.com/blog/genai-langchain-js-fga)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [LangChain Documentation](https://python.langchain.com/)