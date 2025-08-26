# Demo Applications

This document provides a comprehensive overview of the demonstration applications included with the OpenFGA Operator, showcasing fine-grained authorization capabilities in real-world scenarios.

## Overview

The OpenFGA Operator includes two sophisticated demo applications that demonstrate different aspects of implementing fine-grained authorization using OpenFGA:

1. **Banking Application Demo** - A comprehensive financial services application
2. **GenAI RAG Agent Demo** - An AI-powered retrieval-augmented generation system

Both demos illustrate how to integrate OpenFGA for relationship-based access control (ReBAC) in modern microservices architectures.

---

## 🏦 Banking Application Demo

### Purpose
The Banking Application Demo showcases how to implement fine-grained authorization for financial services, demonstrating real-world banking scenarios including account management, transaction processing, and loan approvals with role-based access control.

### Key Features

#### Core Banking Operations
- **Account Management**: Create, view, and manage bank accounts with multiple ownership types
- **Transaction Processing**: Secure money transfers with proper authorization chains
- **Loan Management**: Complete loan application and approval workflows
- **User Management**: Role-based user administration across organizational hierarchies

#### Authorization Model
The demo implements a comprehensive banking authorization model with these entities:

- **Bank**: Top-level financial institution
- **Branch**: Local bank branches with regional management
- **Account**: Customer accounts supporting single and joint ownership
- **Transaction**: Financial transactions with detailed audit trails
- **Loan**: Loan products with multi-step approval processes
- **User**: System users with various roles and permissions

#### Roles and Permissions
- **Customer**: Manage personal accounts and initiate transactions
- **Teller**: Assist customers with account operations within their branch
- **Manager**: Oversee branch operations and approve high-value transactions
- **Loan Officer**: Process and manage loan applications and approvals
- **Admin**: Full system access and user management capabilities

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Banking Demo Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│  Banking API (Node.js/TypeScript)                               │
│  ├── Account Management    ├── Transaction Processing           │
│  ├── Loan Management      └── User Management                   │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                     OpenFGA Authorization                       │
│  ├── Banking Authorization Model                                │
│  ├── Relationship-based Access Control                          │
│  └── Fine-grained Permissions                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Technical Components

#### Core Technologies
- **Node.js/TypeScript**: RESTful API backend
- **OpenFGA SDK**: Authorization integration
- **Express.js**: Web framework
- **Docker**: Containerization support

#### Key Authorization Patterns
- **RBAC Implementation**: Clear role hierarchy with inheritance
- **Multi-ownership Support**: Joint accounts with multiple owners and co-owners
- **Branch-based Access Control**: Employees limited to their branch operations
- **Transaction Security**: Controlled access with approval workflows

### Setup Instructions

#### Quick Start
```bash
# Navigate to banking demo
cd demos/banking-app

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your OpenFGA instance details

# Initialize demo data
npm run setup

# Start the application
npm run dev
```

#### Demo Users
- **alice** (customer) - Account owner with multiple accounts
- **bob** (customer) - Joint account holder
- **charlie** (teller) - Can process deposits and basic operations
- **diana** (manager) - Can approve transactions and manage branch
- **eve** (loan_officer) - Can process and approve loans
- **frank** (admin) - Full system access

#### API Examples
```bash
# Check account balance (as alice)
curl -H "x-user-id: alice" http://localhost:3000/api/accounts

# Transfer money (requires proper authorization)
curl -X POST http://localhost:3000/api/transactions \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"fromAccountId": "acc_12345678", "toAccountId": "acc_87654321", "amount": 100}'

# Apply for loan (customer action)
curl -X POST http://localhost:3000/api/loans \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50000, "type": "personal", "term": 36}'
```

### Documentation Links
- **Detailed Documentation**: [demos/banking-app/README.md](demos/banking-app/README.md)
- **Authorization Model**: [demos/banking-app/models/banking-authorization-model.json](demos/banking-app/models/)
- **API Documentation**: See README for complete endpoint reference

---

## 🤖 GenAI RAG Agent Demo

### Purpose
The GenAI RAG Agent Demo demonstrates how to implement fine-grained authorization in AI-powered applications, specifically for Retrieval-Augmented Generation (RAG) systems with document-level security and AI model access controls.

### Key Features

#### Core RAG Capabilities
- **Knowledge Base Management**: Create and organize document collections
- **Document Upload**: Add documents with metadata and automatic embedding
- **Semantic Search**: Find relevant documents using vector similarity
- **AI Response Generation**: Generate contextual responses using retrieved documents
- **Multiple AI Models**: Support for OpenAI, Anthropic, and other models

#### Authorization Features
The demo implements a sophisticated authorization model with these entities:

- **Organization**: Top-level organizational boundary
- **Knowledge Base**: Collections of documents with curator/contributor/reader roles
- **Document**: Individual documents with owner/editor/viewer permissions
- **AI Model**: AI models with usage and configuration permissions
- **Chat Session**: Conversation sessions with owner/participant access
- **Query**: Individual queries linked to sessions with audit trails

#### Security Roles
- **User**: Basic users with limited access to assigned resources
- **Contributor**: Can add documents to knowledge bases they have access to
- **Curator**: Can manage knowledge bases and their contents
- **Admin**: Full organizational access and user management

### Architecture

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

### Technical Components

#### Core Technologies
- **Python/FastAPI**: High-performance API backend
- **OpenFGA SDK**: Authorization integration
- **LangChain**: AI framework integration
- **Vector Database**: Document embeddings and similarity search
- **Docker**: Containerization support

#### Key Authorization Patterns
- **Document-Level Security**: Individual document permissions with inheritance
- **Content Filtering**: RAG responses filtered based on document access rights
- **AI Model Access Control**: Separate permissions for using and configuring models
- **Session-Based Authorization**: Controlled RAG sessions with participant management

### Setup Instructions

#### Quick Start
```bash
# Navigate to GenAI RAG demo
cd demos/genai-rag-agent

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your OpenFGA and AI model details

# Initialize demo data
python setup.py

# Start the application
python -m uvicorn src.main:app --reload --port 8000
```

#### Demo Users
- **alice** (user) - Can access demo knowledge base and participate in sessions
- **bob** (user) - Limited access to specific documents
- **charlie** (curator) - Can manage knowledge bases and documents
- **diana** (admin) - Full organizational access and user management

#### API Examples
```bash
# List accessible knowledge bases (as alice)
curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases

# Upload document to knowledge base (requires curator access)
curl -X POST http://localhost:8000/api/knowledge-bases/kb_demo/documents \
  -H 'x-user-id: charlie' \
  -H 'Content-Type: application/json' \
  -d '{"title": "AI Ethics Guide", "content": "This document covers...", "metadata": {"category": "ethics"}}'

# Query the RAG system (filtered by permissions)
curl -X POST -H 'Content-Type: application/json' -H 'x-user-id: alice' \
     -d '{"query": "What is this system about?"}' \
     http://localhost:8000/api/chat/sessions/session_demo_alice/query
```

### Documentation Links
- **Detailed Documentation**: [demos/genai-rag-agent/README.md](demos/genai-rag-agent/README.md)
- **Authorization Model**: [demos/genai-rag-agent/models/](demos/genai-rag-agent/models/)
- **API Documentation**: See README for complete endpoint reference

---

## 🚀 Quick Deployment

### Automated Deployment
Use the provided deployment scripts for easy setup:

```bash
# Deploy both demos simultaneously
./scripts/deploy-demos.sh

# Deploy individual demos
./scripts/deploy-banking-demo.sh  # Banking demo only
./scripts/deploy-genai-demo.sh    # GenAI demo only

# Deploy with specific container runtime
CONTAINER_RUNTIME=podman ./scripts/deploy-demos.sh
```

### Prerequisites
- **Kubernetes cluster** with OpenFGA Operator installed
- **kubectl** configured to access your cluster
- **Docker** or **Podman** for container operations
- **Node.js 18+** for banking application
- **Python 3.9+** for GenAI RAG agent

### Environment Setup
Both demos require an OpenFGA instance. Deploy using:

```bash
# Deploy OpenFGA instance
kubectl apply -f examples/basic-openfga.yaml

# Verify deployment
kubectl get openfga -n default
```

---

## 🎯 Learning Objectives

After exploring these demos, you will understand:

### Authorization Concepts
- **Relationship-based Access Control (ReBAC)**: Modern authorization beyond simple RBAC
- **Fine-grained Permissions**: Resource-level and operation-specific controls
- **Context-aware Authorization**: Permissions that depend on situational factors
- **Multi-tenancy Patterns**: Secure isolation in shared environments

### Implementation Patterns
- **OpenFGA Integration**: Best practices for SDK usage and API integration
- **Authorization Model Design**: Structuring entities and relationships effectively
- **Performance Optimization**: Caching strategies and bulk operations
- **Security Best Practices**: Secure defaults and defense in depth

### Architectural Patterns
- **Microservices Authorization**: Distributed authorization in service architectures
- **API Gateway Integration**: Centralized vs. distributed authorization
- **Event-driven Authorization**: Authorization in async processing pipelines
- **Monitoring and Observability**: Tracking authorization decisions and performance

---

## 📚 Additional Resources

### Deployment Guides
- **Quick Start Guide**: [DEMO_QUICKSTART.md](DEMO_QUICKSTART.md)
- **Deployment Scripts**: [scripts/README.md](scripts/README.md)
- **Kubernetes Manifests**: [Examples and configurations](examples/)

### OpenFGA Resources
- **OpenFGA Documentation**: [https://openfga.dev/docs](https://openfga.dev/docs)
- **Authorization Modeling**: [https://openfga.dev/docs/modeling](https://openfga.dev/docs/modeling)
- **OpenFGA Playground**: [https://play.fga.dev](https://play.fga.dev)

### Community and Support
- **Repository Issues**: [GitHub Issues](https://github.com/jralmaraz/authcore-openfga-operator/issues)
- **OpenFGA Community**: [https://openfga.dev/community](https://openfga.dev/community)
- **Main Documentation**: [README.md](README.md)

---

## 🤝 Contributing

To contribute to these demos or add new ones:

1. **Fork the repository** and create a feature branch
2. **Follow the established patterns** in existing demos
3. **Include comprehensive documentation** and setup instructions
4. **Add realistic test scenarios** covering both positive and negative cases
5. **Ensure all tests pass** and authorization models are valid
6. **Submit a pull request** with detailed description of changes

For detailed contribution guidelines, see the main [README.md](README.md) file.