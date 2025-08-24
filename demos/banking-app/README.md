# Banking Application Demo

This demo showcases how to implement fine-grained authorization for a banking application using OpenFGA. The demo includes a comprehensive authorization model that supports realistic banking scenarios with RBAC (Role-Based Access Control), multi-ownership, and transaction controls.

A comprehensive banking microservice that demonstrates fine-grained authorization using OpenFGA. This demo showcases real-world banking scenarios including account management, transactions, and loan processing with role-based access control.

## 🏗️ Architecture

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

## 🎯 Features

### Core Banking Operations
- **Account Management**: Create, view, and manage bank accounts
- **Transaction Processing**: Transfer money between accounts with authorization
- **Loan Management**: Apply for loans, track payments, and manage approvals
- **User Management**: Role-based user administration

### Authorization Model
The demo implements a comprehensive banking authorization model with the following entities:

- **Bank**: The financial institution
- **Branch**: Bank branches with local management
- **Account**: Customer bank accounts with multiple ownership types
- **Transaction**: Money transfers with proper authorization
- **Loan**: Loan products with approval workflows
- **User**: System users with various roles

### Roles and Permissions
- **Customer**: Can manage their own accounts and transactions
- **Teller**: Can assist customers with account operations
- **Manager**: Can oversee branch operations and approve transactions
- **Loan Officer**: Can process and manage loan applications
- **Admin**: Full system access and user management

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- OpenFGA instance running (via OpenFGA Operator)
- kubectl access to Kubernetes cluster

### Local Development

1. **Clone and setup:**
   ```bash
   cd demos/banking-app
   npm install
   cp .env.example .env
   ```

2. **Configure environment:**
   Edit `.env` file with your OpenFGA instance details:
   ```env
   OPENFGA_API_URL=http://localhost:8080
   OPENFGA_STORE_ID=your-store-id
   OPENFGA_AUTH_MODEL_ID=your-model-id
   ```

3. **Initialize demo data:**
   ```bash
   npm run setup
   ```
   This will create the OpenFGA store, upload the authorization model, and setup demo users.

4. **Start the application:**
   ```bash
   npm run dev
   ```

5. **Test the API:**
   ```bash
   curl http://localhost:3000/health
   ```

### Kubernetes Deployment

1. **Deploy OpenFGA instance:**
   ```bash
   kubectl apply -f ../../examples/basic-openfga.yaml
   ```

2. **Build and deploy the banking app:**
   ```bash
   # Build Docker image
   docker build -t banking-demo:latest .
   
   # Deploy to Kubernetes
   kubectl apply -f k8s/
   ```

3. **Setup demo data in Kubernetes:**
   ```bash
   kubectl exec -it deployment/banking-demo-app -- npm run setup
   ```

## 📚 API Documentation

### Authentication
All API requests (except health and user signup) require user identification headers:
```bash
-H "x-user-id: alice"
-H "x-user-role: customer"
-H "x-user-email: alice@example.com"
```

### Demo Users
The setup script creates these demo users:
- `alice` (customer) - Has checking and savings accounts
- `bob` (customer) - Has checking account, co-owner of shared account
- `charlie` (teller) - Can assist customers
- `diana` (manager) - Can manage branch operations
- `eve` (loan_officer) - Can process loans
- `frank` (admin) - Full system access

### API Endpoints

#### Accounts API
```bash
# Create account
curl -X POST http://localhost:3000/api/accounts \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"accountNumber": "12345678", "accountType": "checking", "initialBalance": 1000}'

# Get user accounts
curl -H "x-user-id: alice" http://localhost:3000/api/accounts

# Get account details
curl -H "x-user-id: alice" http://localhost:3000/api/accounts/acc_12345678

# Check balance
curl -H "x-user-id: alice" http://localhost:3000/api/accounts/acc_12345678/balance

# Add authorized user
curl -X POST http://localhost:3000/api/accounts/acc_12345678/authorized-users \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"userId": "bob", "permissions": "view"}'
```

#### Transactions API
```bash
# Transfer money
curl -X POST http://localhost:3000/api/transactions \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"fromAccountId": "acc_alice_checking", "toAccountId": "acc_bob_checking", "amount": 100, "description": "Payment"}'

# Get transaction history
curl -H "x-user-id: alice" http://localhost:3000/api/transactions

# Check transaction status
curl -H "x-user-id: alice" http://localhost:3000/api/transactions/tx_123456/status
```

#### Loans API
```bash
# Apply for loan
curl -X POST http://localhost:3000/api/loans \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"loanType": "auto", "principalAmount": 25000, "termMonths": 60, "purpose": "Car purchase"}'

# Get loan details
curl -H "x-user-id: alice" http://localhost:3000/api/loans/loan_123

# Make payment
curl -X POST http://localhost:3000/api/loans/loan_123/payments \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"amount": 500}'

# Update loan status (loan officer only)
curl -X PATCH http://localhost:3000/api/loans/loan_123/status \
  -H "x-user-id: eve" \
  -H "Content-Type: application/json" \
  -d '{"status": "approved", "reviewNotes": "Good credit history", "loanOfficerId": "eve"}'
```

#### Users API
```bash
# Get user profile
curl -H "x-user-id: alice" http://localhost:3000/api/users/profile

# Get user permissions
curl -H "x-user-id: alice" http://localhost:3000/api/users/permissions

# List all users (admin only)
curl -H "x-user-id: frank" http://localhost:3000/api/users

# Create new user
curl -X POST http://localhost:3000/api/users/signup \
  -H "Content-Type: application/json" \
  -d '{"userId": "john", "firstName": "John", "lastName": "Doe", "email": "john@example.com", "role": "customer"}'
```

## 🔐 Authorization Examples

### Scenario 1: Customer Account Access
```bash
# Alice can view her own accounts
curl -H "x-user-id: alice" http://localhost:3000/api/accounts
# ✅ Returns Alice's accounts

# Bob cannot view Alice's private accounts
curl -H "x-user-id: bob" http://localhost:3000/api/accounts/acc_alice_checking
# ❌ 403 Forbidden

# Bob can view shared account he co-owns
curl -H "x-user-id: bob" http://localhost:3000/api/accounts/acc_shared
# ✅ Returns shared account details
```

### Scenario 2: Transaction Authorization
```bash
# Alice can transfer from her own account
curl -X POST http://localhost:3000/api/transactions \
  -H "x-user-id: alice" \
  -H "Content-Type: application/json" \
  -d '{"fromAccountId": "acc_alice_checking", "toAccountId": "acc_bob_checking", "amount": 50}'
# ✅ Transaction created

# Bob cannot transfer from Alice's account
curl -X POST http://localhost:3000/api/transactions \
  -H "x-user-id: bob" \
  -H "Content-Type: application/json" \
  -d '{"fromAccountId": "acc_alice_checking", "toAccountId": "acc_bob_checking", "amount": 50}'
# ❌ 403 Forbidden
```

### Scenario 3: Role-based Operations
```bash
# Teller can view customer accounts
curl -H "x-user-id: charlie" -H "x-user-role: teller" http://localhost:3000/api/accounts/acc_alice_checking
# ✅ Returns account details

# Manager can approve transactions
curl -X PATCH http://localhost:3000/api/transactions/tx_123/approve \
  -H "x-user-id: diana" -H "x-user-role: manager"
# ✅ Transaction approved

# Customer cannot access admin functions
curl -H "x-user-id: alice" http://localhost:3000/api/users
# ❌ 403 Forbidden
```

## 🧪 Testing Authorization

The demo includes built-in authorization testing:

```bash
# Test basic permissions
curl -H "x-user-id: alice" http://localhost:3000/api/users/permissions

# Expected response:
{
  "userId": "alice",
  "permissions": {
    "bank": {
      "admin": false,
      "employee": false,
      "customer": true,
      "viewer": true
    },
    "branch": {
      "manager": false,
      "teller": false,
      "viewer": false
    }
  },
  "resources": {
    "accounts": {
      "viewable": 3,
      "owned": 2
    },
    "loans": {
      "viewable": 1
    }
  }
}
```

## 🔧 Configuration

### Environment Variables
- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment (development/production)
- `OPENFGA_API_URL`: OpenFGA server URL
- `OPENFGA_STORE_ID`: OpenFGA store identifier
- `OPENFGA_AUTH_MODEL_ID`: Authorization model identifier
- `ALLOWED_ORIGINS`: CORS allowed origins

### OpenFGA Model
The authorization model is defined in `models/banking-authorization-model.json`. Key relationships:

- **Bank**: `admin`, `employee`, `customer`, `viewer`
- **Branch**: `manager`, `teller`, `viewer` (inherits from bank)
- **Account**: `owner`, `co_owner`, `authorized_user`, `viewer`, `editor`
- **Transaction**: `initiator`, `viewer`, `editor` (inherits from account)
- **Loan**: `borrower`, `co_borrower`, `loan_officer`, `viewer`, `editor`

## 🐳 Docker Support

```bash
# Build image
docker build -t banking-demo:latest .

# Run container
docker run -p 3000:3000 \
  -e OPENFGA_API_URL=http://host.docker.internal:8080 \
  -e OPENFGA_STORE_ID=your-store-id \
  -e OPENFGA_AUTH_MODEL_ID=your-model-id \
  banking-demo:latest
```

## 🚀 Production Considerations

### Security
- Implement proper JWT authentication
- Use HTTPS in production
- Enable rate limiting
- Add input validation and sanitization
- Implement audit logging

### Scalability
- Use persistent database instead of in-memory storage
- Implement caching for OpenFGA responses
- Add connection pooling
- Use horizontal pod autoscaling

### Monitoring
- Add Prometheus metrics
- Implement distributed tracing
- Set up health checks and alerts
- Monitor OpenFGA performance

## 🤝 Contributing

This demo is part of the OpenFGA Operator project. To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This demo is licensed under the Apache 2.0 License - see the [LICENSE](../../LICENSE) file for details.

## 🆘 Support

For issues and questions:
- Check the [main documentation](../../README.md)
- Open an issue in the repository
- Join the OpenFGA community discussions

## Authorization Model

The OpenFGA authorization model defines the following entity types and relationships:

### Entity Types

1. **Bank**
   - Relations: `admin`, `manager`, `employee`
   - Supports hierarchical roles where managers inherit employee permissions

2. **Branch** 
   - Relations: `parent_bank`, `manager`, `teller`, `employee`, `admin`
   - Branch employees can perform operations on accounts in their branch
   - Inherits admin permissions from parent bank

3. **Account**
   - Relations: `parent_branch`, `owner`, `co_owner`, `authorized_user`, `can_view`, `can_deposit`, `can_withdraw`, `can_transfer`
   - Supports multi-ownership with joint accounts through co-owners
   - Different permission levels for different operations

4. **Loan**
   - Relations: `parent_branch`, `borrower`, `co_borrower`, `loan_officer`, `can_view`, `can_approve`, `can_modify`
   - Supports loan processing workflows with proper approval chains

5. **Transaction**
   - Relations: `source_account`, `target_account`, `initiated_by`, `can_view`, `can_reverse`
   - Transaction visibility based on account relationships
   - Manager-level permissions for transaction reversals

### Key Features

- **RBAC Implementation**: Clear role hierarchy with customer, teller, manager, loan officer, and admin roles
- **Multi-ownership Support**: Joint accounts with multiple owners and co-owners
- **Fine-grained Permissions**: Different permission levels for viewing, depositing, withdrawing, and transferring
- **Branch-based Access Control**: Employees can only access accounts in their branch
- **Loan Processing Workflow**: Proper authorization chains for loan approval and modification
- **Transaction Security**: Controlled access to transaction data and reversal capabilities

## Demo Scenarios

The demo includes the following test scenarios:

### Account Access Control
- Account owners can view, deposit, withdraw, and transfer
- Co-owners have the same permissions as owners
- Branch tellers can view and process deposits
- Branch managers can view and process withdrawals
- Unauthorized users are denied access

### Loan Processing
- Borrowers and co-borrowers can view their loans
- Loan officers can view, approve, and modify loans
- Branch managers can view and approve loans
- Unauthorized users cannot access loan information

### Transaction Control
- Transaction visibility is based on account ownership
- Only branch managers can reverse transactions
- Proper audit trails for all operations

## Usage

```rust
use crate::demos::banking_app::BankingDemo;

// Create demo instance
let demo = BankingDemo::new();

// Check authorization
let request = AuthorizationRequest {
    user: "user:alice".to_string(),
    relation: "can_view".to_string(),
    object: "account:acc1".to_string(),
};
let response = demo.check_authorization(&request);
assert!(response.allowed);

// Get OpenFGA tuples
let tuples = demo.get_tuples();
println!("Total tuples: {}", tuples.len());
```

## Testing

Run the banking demo tests:

```bash
cargo test banking_demo
```

The tests cover:
- Basic authorization scenarios
- RBAC enforcement
- Multi-ownership support
- Transaction controls
- Loan processing workflows
- Edge cases and unauthorized access attempts

## OpenFGA Model File

The complete OpenFGA authorization model is available in `authorization-model.json` and can be imported into an OpenFGA server for production use.
