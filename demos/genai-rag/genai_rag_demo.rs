use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenAIUser {
    pub id: String,
    pub name: String,
    pub email: String,
    pub role: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Organization {
    pub id: String,
    pub name: String,
    pub admins: Vec<String>,
    pub members: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KnowledgeBase {
    pub id: String,
    pub name: String,
    pub description: String,
    pub parent_org_id: String,
    pub curators: Vec<String>,
    pub contributors: Vec<String>,
    pub readers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Document {
    pub id: String,
    pub title: String,
    pub content: String,
    pub parent_kb_id: String,
    pub owner_id: String,
    pub editors: Vec<String>,
    pub viewers: Vec<String>,
    pub tags: Vec<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AIModel {
    pub id: String,
    pub name: String,
    pub model_type: String,
    pub parent_org_id: String,
    pub operators: Vec<String>,
    pub users: Vec<String>,
    pub config: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RAGSession {
    pub id: String,
    pub name: String,
    pub parent_kb_id: String,
    pub parent_model_id: String,
    pub owner_id: String,
    pub participants: Vec<String>,
    pub created_at: String,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RAGQuery {
    pub id: String,
    pub parent_session_id: String,
    pub initiated_by: String,
    pub query_text: String,
    pub queried_documents: Vec<String>,
    pub response_text: String,
    pub timestamp: String,
    pub confidence_score: f64,
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

pub struct GenAIRAGDemo {
    pub users: HashMap<String, GenAIUser>,
    pub organizations: HashMap<String, Organization>,
    pub knowledge_bases: HashMap<String, KnowledgeBase>,
    pub documents: HashMap<String, Document>,
    pub ai_models: HashMap<String, AIModel>,
    pub rag_sessions: HashMap<String, RAGSession>,
    pub rag_queries: HashMap<String, RAGQuery>,
    pub tuples: Vec<OpenFGATuple>,
}

impl GenAIRAGDemo {
    pub fn new() -> Self {
        let mut demo = GenAIRAGDemo {
            users: HashMap::new(),
            organizations: HashMap::new(),
            knowledge_bases: HashMap::new(),
            documents: HashMap::new(),
            ai_models: HashMap::new(),
            rag_sessions: HashMap::new(),
            rag_queries: HashMap::new(),
            tuples: Vec::new(),
        };
        demo.setup_demo_data();
        demo
    }

    fn setup_demo_data(&mut self) {
        // Create users
        self.add_user("alice", "Alice Smith", "alice@company.com", "curator");
        self.add_user("bob", "Bob Johnson", "bob@company.com", "contributor");
        self.add_user("charlie", "Charlie Brown", "charlie@company.com", "reader");
        self.add_user("diana", "Diana Prince", "diana@company.com", "admin");
        self.add_user("eve", "Eve Adams", "eve@company.com", "model_operator");

        // Create organization
        self.add_organization("org1", "TechCorp AI Division", vec!["diana".to_string()], vec!["alice".to_string(), "bob".to_string(), "charlie".to_string(), "eve".to_string()]);

        // Create knowledge base
        self.add_knowledge_base("kb1", "Technical Documentation", "Technical documentation and best practices", "org1", vec!["alice".to_string()], vec!["bob".to_string()], vec!["charlie".to_string()]);

        // Create documents
        self.add_document("doc1", "API Documentation", "Comprehensive API documentation for the system", "kb1", "alice", vec!["bob".to_string()], vec!["charlie".to_string()], vec!["api".to_string(), "documentation".to_string()]);
        self.add_document("doc2", "Security Guidelines", "Security best practices and guidelines", "kb1", "alice", vec![], vec!["bob".to_string(), "charlie".to_string()], vec!["security".to_string(), "guidelines".to_string()]);
        self.add_document("doc3", "Internal Process", "Internal company processes - confidential", "kb1", "diana", vec![], vec![], vec!["internal".to_string(), "confidential".to_string()]);

        // Create AI model
        self.add_ai_model("model1", "RAG-GPT-4", "language_model", "org1", vec!["eve".to_string()], vec!["alice".to_string(), "bob".to_string(), "charlie".to_string()]);

        // Create RAG session
        self.add_rag_session("session1", "API Help Session", "kb1", "model1", "bob", vec!["charlie".to_string()]);

        // Create RAG query
        self.add_rag_query("query1", "session1", "bob", "How do I authenticate with the API?", vec!["doc1".to_string()], "To authenticate with the API, you need to use OAuth 2.0...", 0.95);

        // Setup OpenFGA tuples
        self.setup_authorization_tuples();
    }

    pub fn add_user(&mut self, id: &str, name: &str, email: &str, role: &str) {
        self.users.insert(id.to_string(), GenAIUser {
            id: id.to_string(),
            name: name.to_string(),
            email: email.to_string(),
            role: role.to_string(),
        });
    }

    pub fn add_organization(&mut self, id: &str, name: &str, admins: Vec<String>, members: Vec<String>) {
        self.organizations.insert(id.to_string(), Organization {
            id: id.to_string(),
            name: name.to_string(),
            admins,
            members,
        });
    }

    pub fn add_knowledge_base(&mut self, id: &str, name: &str, description: &str, parent_org_id: &str, curators: Vec<String>, contributors: Vec<String>, readers: Vec<String>) {
        self.knowledge_bases.insert(id.to_string(), KnowledgeBase {
            id: id.to_string(),
            name: name.to_string(),
            description: description.to_string(),
            parent_org_id: parent_org_id.to_string(),
            curators,
            contributors,
            readers,
        });
    }

    pub fn add_document(&mut self, id: &str, title: &str, content: &str, parent_kb_id: &str, owner_id: &str, editors: Vec<String>, viewers: Vec<String>, tags: Vec<String>) {
        let timestamp = chrono::Utc::now().to_rfc3339();
        self.documents.insert(id.to_string(), Document {
            id: id.to_string(),
            title: title.to_string(),
            content: content.to_string(),
            parent_kb_id: parent_kb_id.to_string(),
            owner_id: owner_id.to_string(),
            editors,
            viewers,
            tags,
            created_at: timestamp.clone(),
            updated_at: timestamp,
        });
    }

    pub fn add_ai_model(&mut self, id: &str, name: &str, model_type: &str, parent_org_id: &str, operators: Vec<String>, users: Vec<String>) {
        let mut config = HashMap::new();
        config.insert("max_tokens".to_string(), "4000".to_string());
        config.insert("temperature".to_string(), "0.7".to_string());

        self.ai_models.insert(id.to_string(), AIModel {
            id: id.to_string(),
            name: name.to_string(),
            model_type: model_type.to_string(),
            parent_org_id: parent_org_id.to_string(),
            operators,
            users,
            config,
        });
    }

    pub fn add_rag_session(&mut self, id: &str, name: &str, parent_kb_id: &str, parent_model_id: &str, owner_id: &str, participants: Vec<String>) {
        let timestamp = chrono::Utc::now().to_rfc3339();
        self.rag_sessions.insert(id.to_string(), RAGSession {
            id: id.to_string(),
            name: name.to_string(),
            parent_kb_id: parent_kb_id.to_string(),
            parent_model_id: parent_model_id.to_string(),
            owner_id: owner_id.to_string(),
            participants,
            created_at: timestamp,
            status: "active".to_string(),
        });
    }

    pub fn add_rag_query(&mut self, id: &str, parent_session_id: &str, initiated_by: &str, query_text: &str, queried_documents: Vec<String>, response_text: &str, confidence_score: f64) {
        let timestamp = chrono::Utc::now().to_rfc3339();
        self.rag_queries.insert(id.to_string(), RAGQuery {
            id: id.to_string(),
            parent_session_id: parent_session_id.to_string(),
            initiated_by: initiated_by.to_string(),
            query_text: query_text.to_string(),
            queried_documents,
            response_text: response_text.to_string(),
            timestamp,
            confidence_score,
        });
    }

    fn setup_authorization_tuples(&mut self) {
        // Organization relationships
        if let Some(org) = self.organizations.get("org1") {
            for admin in &org.admins {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", admin),
                    relation: "admin".to_string(),
                    object: "organization:org1".to_string(),
                });
            }
            for member in &org.members {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", member),
                    relation: "member".to_string(),
                    object: "organization:org1".to_string(),
                });
            }
        }

        // Knowledge base relationships
        for kb in self.knowledge_bases.values() {
            self.tuples.push(OpenFGATuple {
                user: format!("organization:{}", kb.parent_org_id),
                relation: "parent_org".to_string(),
                object: format!("knowledge_base:{}", kb.id),
            });

            for curator in &kb.curators {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", curator),
                    relation: "curator".to_string(),
                    object: format!("knowledge_base:{}", kb.id),
                });
            }

            for contributor in &kb.contributors {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", contributor),
                    relation: "contributor".to_string(),
                    object: format!("knowledge_base:{}", kb.id),
                });
            }

            for reader in &kb.readers {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", reader),
                    relation: "reader".to_string(),
                    object: format!("knowledge_base:{}", kb.id),
                });
            }
        }

        // Document relationships
        for doc in self.documents.values() {
            self.tuples.push(OpenFGATuple {
                user: format!("knowledge_base:{}", doc.parent_kb_id),
                relation: "parent_kb".to_string(),
                object: format!("document:{}", doc.id),
            });

            self.tuples.push(OpenFGATuple {
                user: format!("user:{}", doc.owner_id),
                relation: "owner".to_string(),
                object: format!("document:{}", doc.id),
            });

            for editor in &doc.editors {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", editor),
                    relation: "editor".to_string(),
                    object: format!("document:{}", doc.id),
                });
            }

            for viewer in &doc.viewers {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", viewer),
                    relation: "viewer".to_string(),
                    object: format!("document:{}", doc.id),
                });
            }
        }

        // AI Model relationships
        for model in self.ai_models.values() {
            self.tuples.push(OpenFGATuple {
                user: format!("organization:{}", model.parent_org_id),
                relation: "parent_org".to_string(),
                object: format!("ai_model:{}", model.id),
            });

            for operator in &model.operators {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", operator),
                    relation: "operator".to_string(),
                    object: format!("ai_model:{}", model.id),
                });
            }

            for user in &model.users {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", user),
                    relation: "user".to_string(),
                    object: format!("ai_model:{}", model.id),
                });
            }
        }

        // RAG Session relationships
        for session in self.rag_sessions.values() {
            self.tuples.push(OpenFGATuple {
                user: format!("knowledge_base:{}", session.parent_kb_id),
                relation: "parent_kb".to_string(),
                object: format!("rag_session:{}", session.id),
            });

            self.tuples.push(OpenFGATuple {
                user: format!("ai_model:{}", session.parent_model_id),
                relation: "parent_model".to_string(),
                object: format!("rag_session:{}", session.id),
            });

            self.tuples.push(OpenFGATuple {
                user: format!("user:{}", session.owner_id),
                relation: "owner".to_string(),
                object: format!("rag_session:{}", session.id),
            });

            for participant in &session.participants {
                self.tuples.push(OpenFGATuple {
                    user: format!("user:{}", participant),
                    relation: "participant".to_string(),
                    object: format!("rag_session:{}", session.id),
                });
            }
        }

        // RAG Query relationships
        for query in self.rag_queries.values() {
            self.tuples.push(OpenFGATuple {
                user: format!("rag_session:{}", query.parent_session_id),
                relation: "parent_session".to_string(),
                object: format!("rag_query:{}", query.id),
            });

            self.tuples.push(OpenFGATuple {
                user: format!("user:{}", query.initiated_by),
                relation: "initiated_by".to_string(),
                object: format!("rag_query:{}", query.id),
            });

            for doc_id in &query.queried_documents {
                self.tuples.push(OpenFGATuple {
                    user: format!("document:{}", doc_id),
                    relation: "queried_documents".to_string(),
                    object: format!("rag_query:{}", query.id),
                });
            }
        }
    }

    pub fn check_authorization(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        // Simplified authorization check based on tuples and model logic
        match (request.relation.as_str(), request.object.split(':').next()) {
            ("can_view", Some("knowledge_base")) => self.check_kb_view_permission(request),
            ("can_contribute", Some("knowledge_base")) => self.check_kb_contribute_permission(request),
            ("can_curate", Some("knowledge_base")) => self.check_kb_curate_permission(request),
            ("can_admin", Some("knowledge_base")) => self.check_kb_admin_permission(request),
            ("can_view", Some("document")) => self.check_document_view_permission(request),
            ("can_edit", Some("document")) => self.check_document_edit_permission(request),
            ("can_delete", Some("document")) => self.check_document_delete_permission(request),
            ("can_use_in_rag", Some("document")) => self.check_document_rag_permission(request),
            ("can_use", Some("ai_model")) => self.check_model_use_permission(request),
            ("can_configure", Some("ai_model")) => self.check_model_configure_permission(request),
            ("can_admin", Some("ai_model")) => self.check_model_admin_permission(request),
            ("can_view", Some("rag_session")) => self.check_session_view_permission(request),
            ("can_query", Some("rag_session")) => self.check_session_query_permission(request),
            ("can_access_documents", Some("rag_session")) => self.check_session_document_access_permission(request),
            ("can_view", Some("rag_query")) => self.check_query_view_permission(request),
            ("can_access_results", Some("rag_query")) => self.check_query_results_permission(request),
            _ => AuthorizationResponse {
                allowed: false,
                reason: Some("Unknown permission".to_string()),
            },
        }
    }

    fn check_kb_view_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let kb_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_kb_curator(kb_id, user_id) || self.is_kb_contributor(kb_id, user_id) || self.is_kb_reader(kb_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User has direct KB role".to_string()),
            };
        }

        if self.is_org_member_for_kb(kb_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is organization member".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to view knowledge base".to_string()),
        }
    }

    fn check_kb_contribute_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let kb_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_kb_curator(kb_id, user_id) || self.is_kb_contributor(kb_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is curator or contributor".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to contribute to knowledge base".to_string()),
        }
    }

    fn check_kb_curate_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let kb_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_kb_curator(kb_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is curator".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to curate knowledge base".to_string()),
        }
    }

    fn check_kb_admin_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let kb_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_kb_curator(kb_id, user_id) || self.is_org_admin_for_kb(kb_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is curator or org admin".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to admin knowledge base".to_string()),
        }
    }

    fn check_document_view_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let doc_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        // Direct document permissions (owner, editor, viewer)
        if self.is_document_owner(doc_id, user_id) || self.is_document_editor(doc_id, user_id) || self.is_document_viewer(doc_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User has direct document access".to_string()),
            };
        }

        // For documents with no specific viewers, only owner and explicit roles can access
        if let Some(doc) = self.documents.get(doc_id) {
            if doc.viewers.is_empty() && doc.editors.is_empty() {
                // Confidential documents - only owner or KB curators can access
                if self.can_curate_kb_for_document(doc_id, user_id) {
                    return AuthorizationResponse {
                        allowed: true,
                        reason: Some("User can curate parent knowledge base".to_string()),
                    };
                }
            } else {
                // Documents with explicit permissions - inherit from KB view permissions
                if self.can_view_kb_for_document(doc_id, user_id) {
                    return AuthorizationResponse {
                        allowed: true,
                        reason: Some("User can view parent knowledge base".to_string()),
                    };
                }
            }
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to view document".to_string()),
        }
    }

    fn check_document_edit_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let doc_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_document_owner(doc_id, user_id) || self.is_document_editor(doc_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is document owner or editor".to_string()),
            };
        }

        if self.can_contribute_to_kb_for_document(doc_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User can contribute to parent knowledge base".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to edit document".to_string()),
        }
    }

    fn check_document_delete_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let doc_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_document_owner(doc_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is document owner".to_string()),
            };
        }

        if self.can_curate_kb_for_document(doc_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User can curate parent knowledge base".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to delete document".to_string()),
        }
    }

    fn check_document_rag_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        // For RAG usage, same as view permission
        self.check_document_view_permission(request)
    }

    fn check_model_use_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let model_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_model_operator(model_id, user_id) || self.is_model_user(model_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User has direct model access".to_string()),
            };
        }

        if self.is_org_member_for_model(model_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is organization member".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to use AI model".to_string()),
        }
    }

    fn check_model_configure_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let model_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_model_operator(model_id, user_id) || self.is_org_admin_for_model(model_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is model operator or org admin".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to configure AI model".to_string()),
        }
    }

    fn check_model_admin_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let model_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_model_operator(model_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is model operator".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to admin AI model".to_string()),
        }
    }

    fn check_session_view_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let session_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_session_owner(session_id, user_id) || self.is_session_participant(session_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User is session owner or participant".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to view RAG session".to_string()),
        }
    }

    fn check_session_query_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        // Same as view permission for sessions
        self.check_session_view_permission(request)
    }

    fn check_session_document_access_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let session_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        // Must be able to query session AND view the parent knowledge base
        if (self.is_session_owner(session_id, user_id) || self.is_session_participant(session_id, user_id)) 
            && self.can_view_session_kb(session_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User can query session and view KB documents".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to access documents in RAG session".to_string()),
        }
    }

    fn check_query_view_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let query_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        if self.is_query_initiator(query_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User initiated the query".to_string()),
            };
        }

        if self.can_view_query_session(query_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User can view parent session".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to view RAG query".to_string()),
        }
    }

    fn check_query_results_permission(&self, request: &AuthorizationRequest) -> AuthorizationResponse {
        let query_id = request.object.split(':').nth(1).unwrap_or("");
        let user_id = request.user.split(':').nth(1).unwrap_or("");

        // Must be able to view query AND have access to all queried documents
        if self.check_query_view_permission(request).allowed && self.can_access_all_queried_documents(query_id, user_id) {
            return AuthorizationResponse {
                allowed: true,
                reason: Some("User can view query and access all referenced documents".to_string()),
            };
        }

        AuthorizationResponse {
            allowed: false,
            reason: Some("User not authorized to access query results".to_string()),
        }
    }

    // Helper methods
    fn is_kb_curator(&self, kb_id: &str, user_id: &str) -> bool {
        if let Some(kb) = self.knowledge_bases.get(kb_id) {
            return kb.curators.contains(&user_id.to_string());
        }
        false
    }

    fn is_kb_contributor(&self, kb_id: &str, user_id: &str) -> bool {
        if let Some(kb) = self.knowledge_bases.get(kb_id) {
            return kb.contributors.contains(&user_id.to_string());
        }
        false
    }

    fn is_kb_reader(&self, kb_id: &str, user_id: &str) -> bool {
        if let Some(kb) = self.knowledge_bases.get(kb_id) {
            return kb.readers.contains(&user_id.to_string());
        }
        false
    }

    fn is_org_member_for_kb(&self, kb_id: &str, user_id: &str) -> bool {
        if let Some(kb) = self.knowledge_bases.get(kb_id) {
            if let Some(org) = self.organizations.get(&kb.parent_org_id) {
                return org.members.contains(&user_id.to_string()) || org.admins.contains(&user_id.to_string());
            }
        }
        false
    }

    fn is_org_admin_for_kb(&self, kb_id: &str, user_id: &str) -> bool {
        if let Some(kb) = self.knowledge_bases.get(kb_id) {
            if let Some(org) = self.organizations.get(&kb.parent_org_id) {
                return org.admins.contains(&user_id.to_string());
            }
        }
        false
    }

    fn is_document_owner(&self, doc_id: &str, user_id: &str) -> bool {
        if let Some(doc) = self.documents.get(doc_id) {
            return doc.owner_id == user_id;
        }
        false
    }

    fn is_document_editor(&self, doc_id: &str, user_id: &str) -> bool {
        if let Some(doc) = self.documents.get(doc_id) {
            return doc.editors.contains(&user_id.to_string());
        }
        false
    }

    fn is_document_viewer(&self, doc_id: &str, user_id: &str) -> bool {
        if let Some(doc) = self.documents.get(doc_id) {
            return doc.viewers.contains(&user_id.to_string());
        }
        false
    }

    fn can_view_kb_for_document(&self, doc_id: &str, user_id: &str) -> bool {
        if let Some(doc) = self.documents.get(doc_id) {
            let kb_request = AuthorizationRequest {
                user: format!("user:{}", user_id),
                relation: "can_view".to_string(),
                object: format!("knowledge_base:{}", doc.parent_kb_id),
            };
            return self.check_kb_view_permission(&kb_request).allowed;
        }
        false
    }

    fn can_contribute_to_kb_for_document(&self, doc_id: &str, user_id: &str) -> bool {
        if let Some(doc) = self.documents.get(doc_id) {
            let kb_request = AuthorizationRequest {
                user: format!("user:{}", user_id),
                relation: "can_contribute".to_string(),
                object: format!("knowledge_base:{}", doc.parent_kb_id),
            };
            return self.check_kb_contribute_permission(&kb_request).allowed;
        }
        false
    }

    fn can_curate_kb_for_document(&self, doc_id: &str, user_id: &str) -> bool {
        if let Some(doc) = self.documents.get(doc_id) {
            let kb_request = AuthorizationRequest {
                user: format!("user:{}", user_id),
                relation: "can_curate".to_string(),
                object: format!("knowledge_base:{}", doc.parent_kb_id),
            };
            return self.check_kb_curate_permission(&kb_request).allowed;
        }
        false
    }

    fn is_model_operator(&self, model_id: &str, user_id: &str) -> bool {
        if let Some(model) = self.ai_models.get(model_id) {
            return model.operators.contains(&user_id.to_string());
        }
        false
    }

    fn is_model_user(&self, model_id: &str, user_id: &str) -> bool {
        if let Some(model) = self.ai_models.get(model_id) {
            return model.users.contains(&user_id.to_string());
        }
        false
    }

    fn is_org_member_for_model(&self, model_id: &str, user_id: &str) -> bool {
        if let Some(model) = self.ai_models.get(model_id) {
            if let Some(org) = self.organizations.get(&model.parent_org_id) {
                return org.members.contains(&user_id.to_string()) || org.admins.contains(&user_id.to_string());
            }
        }
        false
    }

    fn is_org_admin_for_model(&self, model_id: &str, user_id: &str) -> bool {
        if let Some(model) = self.ai_models.get(model_id) {
            if let Some(org) = self.organizations.get(&model.parent_org_id) {
                return org.admins.contains(&user_id.to_string());
            }
        }
        false
    }

    fn is_session_owner(&self, session_id: &str, user_id: &str) -> bool {
        if let Some(session) = self.rag_sessions.get(session_id) {
            return session.owner_id == user_id;
        }
        false
    }

    fn is_session_participant(&self, session_id: &str, user_id: &str) -> bool {
        if let Some(session) = self.rag_sessions.get(session_id) {
            return session.participants.contains(&user_id.to_string());
        }
        false
    }

    fn can_view_session_kb(&self, session_id: &str, user_id: &str) -> bool {
        if let Some(session) = self.rag_sessions.get(session_id) {
            let kb_request = AuthorizationRequest {
                user: format!("user:{}", user_id),
                relation: "can_view".to_string(),
                object: format!("knowledge_base:{}", session.parent_kb_id),
            };
            return self.check_kb_view_permission(&kb_request).allowed;
        }
        false
    }

    fn is_query_initiator(&self, query_id: &str, user_id: &str) -> bool {
        if let Some(query) = self.rag_queries.get(query_id) {
            return query.initiated_by == user_id;
        }
        false
    }

    fn can_view_query_session(&self, query_id: &str, user_id: &str) -> bool {
        if let Some(query) = self.rag_queries.get(query_id) {
            let session_request = AuthorizationRequest {
                user: format!("user:{}", user_id),
                relation: "can_view".to_string(),
                object: format!("rag_session:{}", query.parent_session_id),
            };
            return self.check_session_view_permission(&session_request).allowed;
        }
        false
    }

    fn can_access_all_queried_documents(&self, query_id: &str, user_id: &str) -> bool {
        if let Some(query) = self.rag_queries.get(query_id) {
            for doc_id in &query.queried_documents {
                let doc_request = AuthorizationRequest {
                    user: format!("user:{}", user_id),
                    relation: "can_use_in_rag".to_string(),
                    object: format!("document:{}", doc_id),
                };
                if !self.check_document_rag_permission(&doc_request).allowed {
                    return false;
                }
            }
            return true;
        }
        false
    }

    pub fn get_tuples(&self) -> &Vec<OpenFGATuple> {
        &self.tuples
    }

    pub fn get_documents_for_user(&self, user_id: &str) -> Vec<&Document> {
        self.documents.values()
            .filter(|doc| {
                let request = AuthorizationRequest {
                    user: format!("user:{}", user_id),
                    relation: "can_view".to_string(),
                    object: format!("document:{}", doc.id),
                };
                self.check_authorization(&request).allowed
            })
            .collect()
    }

    pub fn get_filtered_rag_response(&self, query_id: &str, user_id: &str) -> Option<String> {
        if let Some(query) = self.rag_queries.get(query_id) {
            let results_request = AuthorizationRequest {
                user: format!("user:{}", user_id),
                relation: "can_access_results".to_string(),
                object: format!("rag_query:{}", query_id),
            };
            
            if self.check_authorization(&results_request).allowed {
                return Some(query.response_text.clone());
            } else {
                return Some("Access denied: Insufficient permissions to view query results".to_string());
            }
        }
        None
    }
}

impl Default for GenAIRAGDemo {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_genai_demo_creation() {
        let demo = GenAIRAGDemo::new();
        assert!(!demo.users.is_empty());
        assert!(!demo.organizations.is_empty());
        assert!(!demo.knowledge_bases.is_empty());
        assert!(!demo.documents.is_empty());
        assert!(!demo.ai_models.is_empty());
        assert!(!demo.rag_sessions.is_empty());
        assert!(!demo.rag_queries.is_empty());
        assert!(!demo.tuples.is_empty());
    }

    #[test]
    fn test_curator_can_view_kb() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(), // curator
            relation: "can_view".to_string(),
            object: "knowledge_base:kb1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_contributor_can_contribute_to_kb() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:bob".to_string(), // contributor
            relation: "can_contribute".to_string(),
            object: "knowledge_base:kb1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_reader_cannot_contribute_to_kb() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:charlie".to_string(), // reader
            relation: "can_contribute".to_string(),
            object: "knowledge_base:kb1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(!response.allowed);
    }

    #[test]
    fn test_org_member_can_view_kb() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:eve".to_string(), // org member but not direct KB role
            relation: "can_view".to_string(),
            object: "knowledge_base:kb1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_document_owner_can_view_document() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(), // owner of doc1
            relation: "can_view".to_string(),
            object: "document:doc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_document_editor_can_edit_document() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:bob".to_string(), // editor of doc1
            relation: "can_edit".to_string(),
            object: "document:doc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_document_viewer_cannot_edit_document() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:charlie".to_string(), // viewer of doc1
            relation: "can_edit".to_string(),
            object: "document:doc1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(!response.allowed);
    }

    #[test]
    fn test_kb_contributor_can_edit_document() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:bob".to_string(), // KB contributor
            relation: "can_edit".to_string(),
            object: "document:doc2".to_string(), // doc2 which bob doesn't directly edit
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_curator_can_delete_document() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(), // curator
            relation: "can_delete".to_string(),
            object: "document:doc2".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_model_operator_can_configure_model() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:eve".to_string(), // model operator
            relation: "can_configure".to_string(),
            object: "ai_model:model1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_model_user_can_use_model() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(), // model user
            relation: "can_use".to_string(),
            object: "ai_model:model1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_model_user_cannot_configure_model() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:alice".to_string(), // model user, not operator
            relation: "can_configure".to_string(),
            object: "ai_model:model1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(!response.allowed);
    }

    #[test]
    fn test_session_owner_can_query() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:bob".to_string(), // session owner
            relation: "can_query".to_string(),
            object: "rag_session:session1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_session_participant_can_view() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:charlie".to_string(), // session participant
            relation: "can_view".to_string(),
            object: "rag_session:session1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_query_initiator_can_view_query() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:bob".to_string(), // query initiator
            relation: "can_view".to_string(),
            object: "rag_query:query1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_authorized_user_can_access_query_results() {
        let demo = GenAIRAGDemo::new();
        let request = AuthorizationRequest {
            user: "user:bob".to_string(), // query initiator
            relation: "can_access_results".to_string(),
            object: "rag_query:query1".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
    }

    #[test]
    fn test_get_filtered_documents() {
        let demo = GenAIRAGDemo::new();
        let docs = demo.get_documents_for_user("alice");
        assert!(!docs.is_empty());
        
        let docs = demo.get_documents_for_user("eve"); // eve has limited access
        // eve can see some docs through org membership but not all
        assert!(docs.len() <= demo.documents.len());
    }

    #[test]
    fn test_get_filtered_rag_response() {
        let demo = GenAIRAGDemo::new();
        
        // Bob should be able to see query results
        let response = demo.get_filtered_rag_response("query1", "bob");
        assert!(response.is_some());
        assert!(response.unwrap().contains("OAuth"));
        
        // Someone without access should not
        let response = demo.get_filtered_rag_response("query1", "diana");
        assert!(response.is_some());
        assert!(response.unwrap().contains("Access denied"));
    }

    #[test]
    fn test_confidential_document_access() {
        let demo = GenAIRAGDemo::new();
        
        // Diana (admin, owner of doc3) can view it
        let request = AuthorizationRequest {
            user: "user:diana".to_string(),
            relation: "can_view".to_string(),
            object: "document:doc3".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(response.allowed);
        
        // Bob (contributor) cannot view confidential doc3
        let request = AuthorizationRequest {
            user: "user:bob".to_string(),
            relation: "can_view".to_string(),
            object: "document:doc3".to_string(),
        };
        let response = demo.check_authorization(&request);
        assert!(!response.allowed);
    }
}