# OpenFGA Operator Demo Applications

This directory contains demonstration applications showcasing the capabilities of the OpenFGA Operator for different use cases.

## Available Demos

### 1. Banking Application Demo (`banking-app/`)
A microservice-based banking application that demonstrates fine-grained authorization for financial operations using OpenFGA.

**Features:**
- Account management with role-based permissions
- Transaction authorization with resource-level controls
- Multi-tenant banking operations
- RESTful API with OpenFGA integration

### 2. GenAI RAG Agent Demo (`genai-rag-agent/`)
A Retrieval Augmented Generation (RAG) agent that uses OpenFGA for authorizing AI operations and data access.

**Features:**
- Document access control for RAG operations
- User-based AI model permissions
- Context-aware authorization for AI responses
- Integration with popular AI frameworks

## Prerequisites

Before running these demos, ensure you have:

1. **Kubernetes cluster** with the OpenFGA Operator installed
2. **kubectl** configured to access your cluster
3. **Docker** for building container images (optional)
4. **Node.js 18+** for the banking application
5. **Python 3.9+** for the GenAI RAG agent

## Quick Start

1. **Deploy OpenFGA instance:**
   ```bash
   kubectl apply -f ../examples/basic-openfga.yaml
   ```

2. **Choose and run a demo:**
   ```bash
   # Banking Application
   cd banking-app && npm install && npm run setup

   # GenAI RAG Agent  
   cd genai-rag-agent && pip install -r requirements.txt && python setup.py
   ```

## Demo Architecture

Both demos follow a similar pattern:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Demo App      │───▶│  OpenFGA API    │───▶│   OpenFGA       │
│   (Banking/AI)  │    │  (Authorization)│    │   Instance      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

Each demo includes:
- Application code with OpenFGA SDK integration
- Authorization models specific to the use case
- Kubernetes deployment manifests
- Setup and usage documentation

## Learning Objectives

After completing these demos, you will understand:

- How to design authorization models for different domains
- Integration patterns for OpenFGA in microservices
- Kubernetes deployment strategies for authorized applications
- Best practices for fine-grained authorization

## Support

For questions or issues with these demos:
- Check the individual demo README files
- Review the main [OpenFGA Operator documentation](../README.md)
- Open an issue in the repository