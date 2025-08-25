use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct AccountParams {
    pub id: String,
    pub account_number: String,
    pub parent_branch_id: String,
    pub owners: Vec<String>,
    pub co_owners: Vec<String>,
    pub balance: f64,
    pub account_type: String,
}

#[derive(Debug, Clone)]
pub struct LoanParams {
    pub id: String,
    pub parent_branch_id: String,
    pub borrower_id: String,
    pub co_borrowers: Vec<String>,
    pub loan_officer_id: String,
    pub amount: f64,
    pub status: String,
    pub interest_rate: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BankingUser {
    pub id: String,
    pub name: String,
    pub role: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Bank {
    pub id: String,
    pub name: String,
    pub admins: Vec<String>,
    pub managers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Branch {
    pub id: String,
    pub name: String,
    pub parent_bank_id: String,
    pub manager_id: Option<String>,
    pub tellers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    pub id: String,
    pub account_number: String,
    pub parent_branch_id: String,
    pub owners: Vec<String>,
    pub co_owners: Vec<String>,
    pub balance: f64,
    pub account_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Loan {
    pub id: String,
    pub parent_branch_id: String,
    pub borrower_id: String,
    pub co_borrowers: Vec<String>,
    pub loan_officer_id: String,
    pub amount: f64,
    pub status: String,
    pub interest_rate: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transaction {
    pub id: String,
    pub source_account_id: Option<String>,
    pub target_account_id: String,
    pub initiated_by: String,
    pub amount: f64,
    pub transaction_type: String,
    pub timestamp: String,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OpenFGATuple {
    pub user: String,
    pub relation: String,
    pub object: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthorizationRequest {
    pub user: String,
    pub relation: String,
    pub object: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthorizationResponse {
    pub allowed: bool,
    pub reason: Option<String>,
}

pub struct BankingDemo {
    pub users: HashMap<String, BankingUser>,
    pub banks: HashMap<String, Bank>,
    pub branches: HashMap<String, Branch>,
    pub accounts: HashMap<String, Account>,
    pub loans: HashMap<String, Loan>,
    pub transactions: HashMap<String, Transaction>,
    pub tuples: Vec<OpenFGATuple>,
}

impl BankingDemo {
    pub fn new() -> Self {
        let mut demo = BankingDemo {
            users: HashMap::new(),
            banks: HashMap::new(),
            branches: HashMap::new(),
            accounts: HashMap::new(),
            loans: HashMap::new(),
            transactions: HashMap::new(),
            tuples: Vec::new(),
        };
        demo.setup_demo_data();
        demo
    }

    fn setup_demo_data(&mut self) {
        // Create users
        self.add_user("alice", "Alice Johnson", "customer");
        self.add_user("bob", "Bob Smith", "customer");
        self.add_user("charlie", "Charlie Brown", "teller");
        self.add_user("diana", "Diana Prince", "manager");
        self.add_user("eve", "Eve Adams", "loan_officer");
        self.add_user("frank", "Frank Miller", "admin");

        // Create bank
        self.add_bank("bank1", "First National Bank", vec!["frank".to_string()], vec!["diana".to_string()]);

        // Create branch
        self.add_branch("branch1", "Downtown Branch", "bank1", Some("diana".to_string()), vec!["charlie".to_string()]);

        // Create accounts
        self.add_account("acc1", "1001", "branch1", vec!["alice".to_string()], vec![], 5000.0, "checking");
        self.add_account("acc2", "1002", "branch1", vec!["bob".to_string()], vec!["alice".to_string()], 3000.0, "savings");

        // Create loan
        self.add_loan("loan1", "branch1", "alice", vec!["bob".to_string()], "eve", 50000.0, "pending", 3.5);

        // Setup OpenFGA tuples
        self.setup_authorization_tuples();
    }

    pub fn add_user(&mut self, id: &str, name: &str, role: &str) {
        self.users.insert(id.to_string(), BankingUser {
            id: id.to_string(),
            name: name.to_string(),
            role: role.to_string(),
        });
    }

    pub fn add_bank(&mut self, id: &str, name: &str, admins: Vec<String>, managers: Vec<String>) {
        self.banks.insert(id.to_string(), Bank {
            id: id.to_string(),
            name: name.to_string(),
            admins,
            managers,
        });
    }

    pub fn add_branch(&mut self, id: &str, name: &str, parent_bank_id: &str, manager_id: Option<String>, tellers: Vec<String>) {
        self.branches.insert(id.to_string(), Branch {
            id: id.to_string(),
            name: name.to_string(),
            parent_bank_id: parent_bank_id.to_string(),
            manager_id,
            tellers,
        });
    }

    pub fn add_account_with_params(&mut self, params: AccountParams) {
        self.accounts.insert(params.id.clone(), Account {
            id: params.id,
            account_number: params.account_number,
            parent_branch_id: params.parent_branch_id,
            owners: params.owners,
            co_owners: params.co_owners,
            balance: params.balance,
            account_type: params.account_type,
        });
    }

    #[allow(clippy::too_many_arguments)]
    pub fn add_account(&mut self, id: &str, account_number: &str, parent_branch_id: &str, owners: Vec<String>, co_owners: Vec<String>, balance: f64, account_type: &str) {
        let params = AccountParams {
            id: id.to_string(),
            account_number: account_number.to_string(),
            parent_branch_id: parent_branch_id.to_string(),
            owners,
            co_owners,
            balance,
            account_type: account_type.to_string(),
        };
        self.add_account_with_params(params);
    }

    pub fn add_loan_with_params(&mut self, params: LoanParams) {
        self.loans.insert(params.id.clone(), Loan {
            id: params.id,
            parent_branch_id: params.parent_branch_id,
            borrower_id: params.borrower_id,
            co_borrowers: params.co_borrowers,
            loan_officer_id: params.loan_officer_id,
            amount: params.amount,
            status: params.status,
            interest_rate: params.interest_rate,
        });
    }

    #[allow(clippy::too_many_arguments)]
    pub fn add_loan(&mut self, id: &str, parent_branch_id: &str, borrower_id: &str, co_borrowers: Vec<String>, loan_officer_id: &str, amount: f64, status: &str, interest_rate: f64) {
        let params = LoanParams {
            id: id.to_string(),
            parent_branch_id: parent_branch_id.to_string(),
            borrower_id: borrower_id.to_string(),
            co_borrowers,
            loan_officer_id: loan_officer_id.to_string(),
            amount,
            status: status.to_string(),
            interest_rate,
        };
        self.add_loan_with_params(params);
    }

    pub fn add_transaction(&mut self, id: &str, source_account_id: Option<String>, target_account_id: &str, initiated_by: &str, amount: f64, transaction_type: &str) {
        let timestamp = chrono::Utc::now().to_rfc3339();
        self.transactions.insert(id.to_string(), Transaction {
            id: id.to_string(),
            source_account_id,
            target_account_id: target_account_id.to_string(),
            initiated_by: initiated_by.to_string(),
            amount,
            transaction_type: transaction_type.to_string(),
            timestamp,
            status: "completed".to_string(),
        });
    }

    fn setup_authorization_tuples(&mut self) {
        // Bank admin relationships
        if let Some(bank) = self.banks.get("bank1") {
            for admin in &bank.admins {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", admin),
                    relation: "admin".to_string(),
                    object: "bank:bank1".to_string(),
                });
            }
            for manager in &bank.managers {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", manager),
                    relation: "manager".to_string(),
                    object: "bank:bank1".to_string(),
                });
            }
        }

        // Branch relationships
        if let Some(branch) = self.branches.get("branch1") {
            self.tuples.push(OpenFGATuple {
                user: "bank:bank1".to_string(),
                relation: "parent_bank".to_string(),
                object: "branch:branch1".to_string(),
            });

            if let Some(manager_id) = &branch.manager_id {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", manager_id),
                    relation: "manager".to_string(),
                    object: "branch:branch1".to_string(),
                });
            }

            for teller in &branch.tellers {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", teller),
                    relation: "teller".to_string(),
                    object: "branch:branch1".to_string(),
                });
            }
        }

        // Account relationships
        for account in self.accounts.values() {
            self.tuples.push(OpenFGATuple {
                user: format!("branch:{}", account.parent_branch_id),
                relation: "parent_branch".to_string(),
                object: format!("account:{}", account.id),
            });

            for owner in &account.owners {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", owner),
                    relation: "owner".to_string(),
                    object: format!("account:{}", account.id),
                });
            }

            for co_owner in &account.co_owners {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", co_owner),
                    relation: "co_owner".to_string(),
                    object: format!("account:{}", account.id),
                });
            }
        }

        // Loan relationships
        for loan in self.loans.values() {
            self.tuples.push(OpenFGATuple {
                user: format!("branch:{}", loan.parent_branch_id),
                relation: "parent_branch".to_string(),
                object: format!("loan:{}", loan.id),
            });

            self.tuples.push(OpenFGATuple {
                user: format!("user:{}", loan.borrower_id),
                relation: "borrower".to_string(),
                object: format!("loan:{}", loan.id),
            });

            for co_borrower in &loan.co_borrowers {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", co_borrower),
                    relation: "co_borrower".to_string(),
                    object: format!("loan:{}", loan.id),
                });
            }

            self.tuples.push(OpenFGATuple {
                user: format!("user:{}", loan.loan_officer_id),
                relation: "loan_officer".to_string(),
                object: format!("loan:{}", loan.id),
            });
        }
    }

    pub fn check_authorization(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        // Simplified authorization check based on tuples and model logic
        match (request.relation.as_str(), request.object.split(':').next()) {
            ("can_view", Some("account")) => self.check_account_view_permission(request),
            ("can_deposit", Some("account")) => self.check_account_deposit_permission(request),
            ("can_withdraw", Some("account")) => self.check_account_withdraw_permission(request),
            ("can_transfer", Some("account")) => self.check_account_transfer_permission(request),
            ("can_view", Some("loan")) => self.check_loan_view_permission(request),
            ("can_approve", Some("loan")) => self.check_loan_approve_permission(request),
            ("can_modify", Some("loan")) => self.check_loan_modify_permission(request),
            _ => AuthorizationResponse {
                allowed: false,
                reason: Some("Unknown permission".to_string()),
            },
        }
    }

    fn check_account_view_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let account_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        // Check if user is owner or co-owner
        if self.is_account_authorized_user(account_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is account owner/co-owner".to_string()),
            };
        }

        // Check if user is branch employee
        if self.is_branch_employee(account_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is branch employee".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to view account".to_string()),
        }
    }

    fn check_account_deposit_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let account_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        // Check if user is authorized user or branch teller
        if self.is_account_authorized_user(account_id, user_id) || self.is_branch_teller(account_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User authorized for deposits".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized for deposits".to_string()),
        }
    }

    fn check_account_withdraw_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let account_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        // Check if user is authorized user or branch manager
        if self.is_account_authorized_user(account_id, user_id) || self.is_branch_manager(account_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User authorized for withdrawals".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized for withdrawals".to_string()),
        }
    }

    fn check_account_transfer_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let account_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_account_authorized_user(account_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User authorized for transfers".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized for transfers".to_string()),
        }
    }

    fn check_loan_view_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let loan_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if let Some(loan) = self.loans.get(loan_id) {
            // Check if user is borrower, co-borrower, loan officer, or branch manager
            if loan.borrower_id == user_id 
                || loan.co_borrowers.contains(&user_id.to_string())
                || loan.loan_officer_id == user_id
                || self.is_loan_branch_manager(loan_id, user_id) {
                return AuthorizationResponse {
                    allowed: true,
                    reason: Some("User authorized to view loan".to_string()),
                };
            }
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to view loan".to_string()),
        }
    }

    fn check_loan_approve_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let loan_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if let Some(loan) = self.loans.get(loan_id) {
            // Check if user is loan officer or branch manager
            if loan.loan_officer_id == user_id || self.is_loan_branch_manager(loan_id, user_id) {
                return AuthorizationResponse {
                    allowed: true,
                    reason: Some("User authorized to approve loan".to_string()),
                };
            }
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to approve loan".to_string()),
        }
    }

    fn check_loan_modify_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let loan_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if let Some(loan) = self.loans.get(loan_id) {
            if loan.loan_officer_id == user_id {
                return AuthorizationResponse {
                    allowed: true,
                    reason: Some("User authorized to modify loan".to_string()),
                };
            }
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to modify loan".to_string()),
        }
    }

    // Helper methods
    fn is_account_authorized_user(&self, account_id: &str, user_id: &str) -> bool {
        if let Some(account) = self.accounts.get(account_id) {
            return account.owners.contains(&user_id.to_string()) 
                || account.co_owners.contains(&user_id.to_string());
        }
        false
    }

    fn is_branch_employee(&self, account_id: &str, user_id: &str) -> bool {
        self.is_branch_teller(account_id, user_id) || self.is_branch_manager(account_id, user_id)
    }

    fn is_branch_teller(&self, account_id: &str, user_id: &str) -> bool {
        if let Some(account) = self.accounts.get(account_id) {
            if let Some(branch) = self.branches.get(&account.parent_branch_id) {
                return branch.tellers.contains(&user_id.to_string());
            }
        }
        false
    }

    fn is_branch_manager(&self, account_id: &str, user_id: &str) -> bool {
        if let Some(account) = self.accounts.get(account_id) {
            if let Some(branch) = self.branches.get(&account.parent_branch_id) {
                return branch.manager_id.as_ref() == Some(&user_id.to_string());
            }
        }
        false
    }

    fn is_loan_branch_manager(&self, loan_id: &str, user_id: &str) -> bool {
        if let Some(loan) = self.loans.get(loan_id) {
            if let Some(branch) = self.branches.get(&loan.parent_branch_id) {
                return branch.manager_id.as_ref() == Some(&user_id.to_string());
            }
        }
        false
    }

    pub fn get_tuples(&self) -> &Vec<OpenFGATuple> {
        &self.tuples
    }
}

impl Default for BankingDemo {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_banking_demo_creation() {
        let demo = BankingDemo::new();
        assert!(!demo.users.is_empty());
        assert!(!demo.banks.is_empty());
        assert!(!demo.branches.is_empty());
        assert!(!demo.accounts.is_empty());
        assert!(!demo.loans.is_empty());
        assert!(!demo.tuples.is_empty());
    }

    #[test]
    fn test_account_owner_can_view() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(),
            relation: "can_view".to_string(),
            object: "account:acc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_account_co_owner_can_view() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(),
            relation: "can_view".to_string(),
            object: "account:acc2".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_branch_employee_can_view_account() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:charlie".to_string(), // teller
            relation: "can_view".to_string(),
            object: "account:acc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_unauthorized_user_cannot_view_account() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:eve".to_string(), // loan officer, not related to account
            relation: "can_view".to_string(),
            object: "account:acc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(!response.allowed);
    }

    #[test]
    fn test_owner_can_transfer() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(),
            relation: "can_transfer".to_string(),
            object: "account:acc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_teller_can_deposit() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:charlie".to_string(), // teller
            relation: "can_deposit".to_string(),
            object: "account:acc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_manager_can_withdraw() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:diana".to_string(), // branch manager
            relation: "can_withdraw".to_string(),
            object: "account:acc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_loan_officer_can_view_loan() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:eve".to_string(), // loan officer
            relation: "can_view".to_string(),
            object: "loan:loan1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_borrower_can_view_loan() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(), // borrower
            relation: "can_view".to_string(),
            object: "loan:loan1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_loan_officer_can_approve_loan() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:eve".to_string(), // loan officer
            relation: "can_approve".to_string(),
            object: "loan:loan1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_loan_officer_can_modify_loan() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:eve".to_string(), // loan officer
            relation: "can_modify".to_string(),
            object: "loan:loan1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_unauthorized_user_cannot_approve_loan() {
        let demo = BankingDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(), // borrower, not loan officer
            relation: "can_approve".to_string(),
            object: "loan:loan1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(!response.allowed);
    }
}