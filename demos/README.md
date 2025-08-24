# OpenFGA Operator Demo Applications

This directory contains comprehensive demo applications showcasing the OpenFGA operator's capabilities for implementing fine-grained authorization in real-world scenarios.

## Demo Applications

### 1. Banking Application Demo
**Location**: `banking-app/`

A comprehensive banking application demonstrating:
- **RBAC Implementation**: Customer, teller, manager, loan officer, and admin roles
- **Multi-ownership Support**: Joint accounts with multiple owners and co-owners
- **Transaction Controls**: Fine-grained permissions for deposits, withdrawals, and transfers
- **Loan Processing**: Approval workflows with proper authorization chains
- **Branch-based Security**: Employee access limited to their branch

**Key Features**:
- Bank-branch-account hierarchy
- Multi-ownership for joint accounts
- Role-based transaction permissions
- Loan officer workflows
- Manager override capabilities

### 2. GenAI RAG Agent Demo
**Location**: `genai-rag/`

A Generative AI RAG (Retrieval-Augmented Generation) application demonstrating:
- **Knowledge Base Management**: Curator, contributor, and reader roles
- **Document-Level Security**: Individual document permissions with inheritance
- **Content Filtering**: RAG responses filtered based on document access rights
- **AI Model Access Control**: Separate permissions for using and configuring models
- **Session-Based RAG**: Controlled RAG sessions with participant management

**Key Features**:
- Three-tier role system for knowledge management
- Document-level permissions with inheritance
- Content filtering for RAG responses
- AI model usage and configuration controls
- Session-based access with intersection permissions

## Architecture

Both demos implement the following architectural patterns:

### Authorization Models
- **OpenFGA DSL Format**: Complete authorization models in JSON format
- **Relationship-Based**: Tuples defining relationships between users and resources
- **Hierarchical Permissions**: Role inheritance and computed relationships
- **Intersection Logic**: Complex permission combinations using OpenFGA's operators

### Demo Structure
```
demos/
├── banking-app/
│   ├── authorization-model.json    # OpenFGA model definition
│   ├── banking_demo.rs            # Demo implementation
│   └── README.md                  # Documentation
├── genai-rag/
│   ├── authorization-model.json    # OpenFGA model definition
│   ├── genai_rag_demo.rs          # Demo implementation
│   └── README.md                  # Documentation
└── README.md                      # This file
```

### Code Organization
- **Data Models**: Structs representing entities (users, accounts, documents, etc.)
- **Authorization Logic**: Implementation of OpenFGA authorization checks
- **Test Scenarios**: Comprehensive test coverage for all authorization scenarios
- **Helper Methods**: Utility functions for common authorization patterns

## Running the Demos

### Prerequisites
```bash
# Ensure you have Rust installed
rustc --version

# Navigate to the project root
cd /path/to/authcore-openfga-operator
```

### Build and Test
```bash
# Build the project with demos
cargo build

# Run all tests including demo tests
cargo test

# Run only banking demo tests
cargo test banking_demo

# Run only GenAI RAG demo tests
cargo test genai_rag_demo

# Run with verbose output
cargo test -- --nocapture
```

### Integration with OpenFGA

The authorization models can be imported into a running OpenFGA server:

```bash
# Start OpenFGA server (example using Docker)
docker run -p 8080:8080 openfga/openfga run

# Import banking model
curl -X POST http://localhost:8080/stores \
  -H "Content-Type: application/json" \
  -d @demos/banking-app/authorization-model.json

# Import GenAI model
curl -X POST http://localhost:8080/stores \
  -H "Content-Type: application/json" \
  -d @demos/genai-rag/authorization-model.json
```

## Key Authorization Patterns Demonstrated

### 1. Role-Based Access Control (RBAC)
Both demos implement hierarchical RBAC where higher-level roles inherit permissions from lower-level roles.

### 2. Multi-ownership
The banking demo shows how to handle joint accounts and shared resources with multiple owners.

### 3. Contextual Permissions
Permissions that depend on the context (e.g., branch employees can only access accounts in their branch).

### 4. Content Filtering
The GenAI demo shows how to filter content in responses based on user permissions.

### 5. Intersection Permissions
Complex authorization logic where users need multiple permissions simultaneously.

### 6. Hierarchical Inheritance
Permissions that cascade down organizational hierarchies.

## Testing Approach

Each demo includes comprehensive tests covering:

### Positive Test Cases
- Users with proper permissions can perform authorized actions
- Role inheritance works correctly
- Multi-ownership scenarios function properly

### Negative Test Cases  
- Users without permissions are denied access
- Unauthorized operations are blocked
- Cross-organizational access is prevented

### Edge Cases
- Boundary conditions for role hierarchies
- Complex permission intersections
- Cascading permission changes

## Production Deployment

These demos serve as templates for production applications:

1. **Model Deployment**: Import the authorization models into your OpenFGA server
2. **Tuple Management**: Implement tuple creation/deletion for your entities
3. **Authorization Checks**: Integrate the authorization logic into your application
4. **Performance Optimization**: Add caching and bulk operations as needed

## Documentation

Each demo includes detailed documentation covering:
- Authorization model explanation
- Entity relationships
- Permission matrices
- Usage examples
- Test scenarios

See the individual README files in each demo directory for detailed information.

## Contributing

When adding new demo applications:

1. Follow the established directory structure
2. Include comprehensive OpenFGA authorization model
3. Implement realistic test scenarios
4. Add thorough documentation
5. Ensure all tests pass

## References

- [OpenFGA Documentation](https://openfga.dev/docs)
- [OpenFGA Authorization Models](https://openfga.dev/docs/modeling/getting-started)
- [Relationship-Based Access Control](https://openfga.dev/docs/concepts#what-is-relationship-based-access-control-rebac)