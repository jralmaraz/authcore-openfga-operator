# Banking Application Demo

This demo showcases how to implement fine-grained authorization for a banking application using OpenFGA. The demo includes a comprehensive authorization model that supports realistic banking scenarios with RBAC (Role-Based Access Control), multi-ownership, and transaction controls.

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