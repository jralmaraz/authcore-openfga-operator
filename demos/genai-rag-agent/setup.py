#!/usr/bin/env python3
"""
Setup script for GenAI RAG Agent demo with OpenFGA authorization
"""

import asyncio
import json
import logging
import os
from pathlib import Path
from datetime import datetime

from src.services.openfga_service import OpenFGAService, format_user, format_object

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def setup_demo():
    """Setup GenAI RAG Agent demo with OpenFGA"""
    logger.info("🤖 Setting up GenAI RAG Agent Demo with OpenFGA...")
    
    try:
        # Initialize OpenFGA service
        openfga_service = OpenFGAService()
        
        # 1. Create OpenFGA Store
        logger.info("📊 Creating OpenFGA store...")
        store_id = await openfga_service.create_store("genai-rag-demo")
        if not store_id:
            raise Exception("Failed to create OpenFGA store")
        logger.info(f"✅ Store created with ID: {store_id}")
        
        # 2. Load and write authorization model
        logger.info("📋 Writing authorization model...")
        model_path = Path(__file__).parent / "models" / "genai-authorization-model.json"
        with open(model_path, 'r') as f:
            model_data = json.load(f)
        
        auth_model_id = await openfga_service.write_authorization_model(model_data)
        if not auth_model_id:
            raise Exception("Failed to write authorization model")
        logger.info(f"✅ Authorization model written with ID: {auth_model_id}")
        
        # Update service configuration
        openfga_service.store_id = store_id
        openfga_service.auth_model_id = auth_model_id
        
        # 3. Set up demo data
        logger.info("🏢 Setting up demo organization...")
        await setup_demo_organization(openfga_service)
        
        logger.info("👥 Setting up demo users...")
        await setup_demo_users(openfga_service)
        
        logger.info("📚 Setting up demo knowledge bases...")
        await setup_demo_knowledge_bases(openfga_service)
        
        logger.info("🤖 Setting up demo AI models...")
        await setup_demo_ai_models(openfga_service)
        
        logger.info("💬 Setting up demo chat sessions...")
        await setup_demo_chat_sessions(openfga_service)
        
        # 4. Display connection info
        logger.info("\n🎉 Demo setup complete!")
        logger.info("\n📝 Environment variables to set:")
        logger.info(f"OPENFGA_STORE_ID={store_id}")
        logger.info(f"OPENFGA_AUTH_MODEL_ID={auth_model_id}")
        logger.info(f"OPENFGA_API_URL={os.getenv('OPENFGA_API_URL', 'http://localhost:8080')}")
        
        logger.info("\n🔧 Demo users created:")
        logger.info("- alice (user) - Can access demo knowledge base")
        logger.info("- bob (user) - Limited access")
        logger.info("- charlie (curator) - Can manage knowledge bases")
        logger.info("- diana (admin) - Full organization access")
        
        logger.info("\n📚 API Examples:")
        logger.info("# List knowledge bases:")
        logger.info("curl -H 'x-user-id: alice' http://localhost:8000/api/knowledge-bases")
        
        logger.info("\n# Submit a query:")
        logger.info("curl -X POST http://localhost:8000/api/chat/sessions \\")
        logger.info("  -H 'x-user-id: alice' \\")
        logger.info("  -H 'Content-Type: application/json' \\")
        logger.info("  -d '{\"name\": \"Demo Chat\", \"organization_id\": \"demo-org\", \"knowledge_base_ids\": [\"kb_demo\"], \"model_id\": \"gpt-3.5-turbo\"}'")
        
        logger.info("\n# Ask a question:")
        logger.info("curl -X POST http://localhost:8000/api/chat/sessions/SESSION_ID/query \\")
        logger.info("  -H 'x-user-id: alice' \\")
        logger.info("  -H 'Content-Type: application/json' \\")
        logger.info("  -d '{\"question\": \"What is OpenFGA and how does it work?\"}'")
        
    except Exception as e:
        logger.error(f"❌ Setup failed: {e}")
        raise

async def setup_demo_organization(openfga_service: OpenFGAService):
    """Set up demo organization structure"""
    org_obj = format_object("demo-org", "organization")
    # Organization object created implicitly when users are assigned to it
    logger.info("✅ Demo organization structure ready")

async def setup_demo_users(openfga_service: OpenFGAService):
    """Set up demo users with different roles"""
    users = [
        {"id": "alice", "role": "member"},
        {"id": "bob", "role": "member"},
        {"id": "charlie", "role": "member"},  # Will be curator of KB
        {"id": "diana", "role": "admin"}
    ]
    
    tuples = []
    org_obj = format_object("demo-org", "organization")
    
    for user in users:
        user_obj = format_user(user["id"])
        tuples.append({"user": user_obj, "relation": user["role"], "object": org_obj})
    
    await openfga_service.write_tuples(tuples)
    logger.info(f"✅ Created {len(users)} demo users")

async def setup_demo_knowledge_bases(openfga_service: OpenFGAService):
    """Set up demo knowledge bases and documents"""
    knowledge_bases = [
        {"id": "kb_demo", "curator": "charlie"},
        {"id": "kb_public", "curator": "diana"},
        {"id": "kb_private", "curator": "diana"}
    ]
    
    tuples = []
    org_obj = format_object("demo-org", "organization")
    
    # Alice gets reader access to demo KB
    alice_obj = format_user("alice")
    demo_kb_obj = format_object("kb_demo", "knowledge_base")
    tuples.append({"user": alice_obj, "relation": "reader", "object": demo_kb_obj})
    
    for kb in knowledge_bases:
        kb_obj = format_object(kb["id"], "knowledge_base")
        curator_obj = format_user(kb["curator"])
        
        tuples.extend([
            {"user": curator_obj, "relation": "curator", "object": kb_obj},
            {"user": org_obj, "relation": "organization", "object": kb_obj}
        ])
        
        # Set up sample documents
        for i in range(3):
            doc_id = f"doc_{kb['id']}_{i}"
            doc_obj = format_object(doc_id, "document")
            tuples.extend([
                {"user": curator_obj, "relation": "owner", "object": doc_obj},
                {"user": org_obj, "relation": "organization", "object": doc_obj}
            ])
    
    await openfga_service.write_tuples(tuples)
    logger.info(f"✅ Created {len(knowledge_bases)} knowledge bases with sample documents")

async def setup_demo_ai_models(openfga_service: OpenFGAService):
    """Set up demo AI models with access controls"""
    models = [
        {"id": "gpt-3.5-turbo", "users": ["alice", "bob", "charlie", "diana"]},
        {"id": "gpt-4", "users": ["charlie", "diana"]},
        {"id": "claude-2", "users": ["diana"]}
    ]
    
    tuples = []
    org_obj = format_object("demo-org", "organization")
    
    for model in models:
        model_obj = format_object(model["id"], "ai_model")
        tuples.append({"user": org_obj, "relation": "organization", "object": model_obj})
        
        for user_id in model["users"]:
            user_obj = format_user(user_id)
            tuples.append({"user": user_obj, "relation": "user", "object": model_obj})
    
    await openfga_service.write_tuples(tuples)
    logger.info(f"✅ Created {len(models)} AI models with access controls")

async def setup_demo_chat_sessions(openfga_service: OpenFGAService):
    """Set up demo chat sessions"""
    sessions = [
        {"id": "session_alice_demo", "owner": "alice"},
        {"id": "session_charlie_work", "owner": "charlie", "participants": ["alice"]},
        {"id": "session_diana_admin", "owner": "diana"}
    ]
    
    tuples = []
    org_obj = format_object("demo-org", "organization")
    
    for session in sessions:
        session_obj = format_object(session["id"], "chat_session")
        owner_obj = format_user(session["owner"])
        
        tuples.extend([
            {"user": owner_obj, "relation": "owner", "object": session_obj},
            {"user": org_obj, "relation": "organization", "object": session_obj}
        ])
        
        # Add participants if specified
        for participant_id in session.get("participants", []):
            participant_obj = format_user(participant_id)
            tuples.append({"user": participant_obj, "relation": "participant", "object": session_obj})
    
    await openfga_service.write_tuples(tuples)
    logger.info(f"✅ Created {len(sessions)} demo chat sessions")

if __name__ == "__main__":
    asyncio.run(setup_demo())