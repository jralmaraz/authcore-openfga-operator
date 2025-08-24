import os
import logging
from typing import List, Dict, Any, Optional
import json
import httpx
from datetime import datetime

logger = logging.getLogger(__name__)

class OpenFGAService:
    """Service for interacting with OpenFGA for authorization"""
    
    def __init__(self):
        self.api_url = os.getenv("OPENFGA_API_URL", "http://localhost:8080")
        self.store_id = os.getenv("OPENFGA_STORE_ID", "")
        self.auth_model_id = os.getenv("OPENFGA_AUTH_MODEL_ID", "")
        
        if not self.store_id:
            logger.warning("OPENFGA_STORE_ID not set - OpenFGA operations will fail")
        if not self.auth_model_id:
            logger.warning("OPENFGA_AUTH_MODEL_ID not set - OpenFGA operations will fail")
    
    async def check(self, user: str, relation: str, object: str) -> bool:
        """Check if a user has a specific relation to an object"""
        if not self.store_id or not self.auth_model_id:
            logger.warning("OpenFGA not configured, allowing access")
            return True
            
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.api_url}/stores/{self.store_id}/check",
                    json={
                        "tuple_key": {
                            "user": user,
                            "relation": relation,
                            "object": object
                        },
                        "authorization_model_id": self.auth_model_id
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result.get("allowed", False)
                else:
                    logger.error(f"OpenFGA check failed: {response.status_code} - {response.text}")
                    return False
                    
        except Exception as e:
            logger.error(f"OpenFGA check error: {e}")
            return False
    
    async def list_objects(self, user: str, relation: str, type: str) -> List[str]:
        """List objects that a user has a specific relation with"""
        if not self.store_id or not self.auth_model_id:
            logger.warning("OpenFGA not configured, returning empty list")
            return []
            
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.api_url}/stores/{self.store_id}/list-objects",
                    json={
                        "user": user,
                        "relation": relation,
                        "type": type,
                        "authorization_model_id": self.auth_model_id
                    }
                )
                
                if response.status_code == 200:
                    result = response.json()
                    return result.get("objects", [])
                else:
                    logger.error(f"OpenFGA list-objects failed: {response.status_code} - {response.text}")
                    return []
                    
        except Exception as e:
            logger.error(f"OpenFGA list-objects error: {e}")
            return []
    
    async def write_tuples(self, tuples: List[Dict[str, str]]) -> bool:
        """Write relationship tuples to OpenFGA"""
        if not self.store_id or not self.auth_model_id:
            logger.warning("OpenFGA not configured, skipping tuple write")
            return True
            
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.api_url}/stores/{self.store_id}/write",
                    json={
                        "writes": [
                            {
                                "tuple_key": {
                                    "user": tuple["user"],
                                    "relation": tuple["relation"],
                                    "object": tuple["object"]
                                }
                            }
                            for tuple in tuples
                        ],
                        "authorization_model_id": self.auth_model_id
                    }
                )
                
                return response.status_code == 200
                
        except Exception as e:
            logger.error(f"OpenFGA write error: {e}")
            return False
    
    async def delete_tuples(self, tuples: List[Dict[str, str]]) -> bool:
        """Delete relationship tuples from OpenFGA"""
        if not self.store_id or not self.auth_model_id:
            logger.warning("OpenFGA not configured, skipping tuple delete")
            return True
            
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.api_url}/stores/{self.store_id}/write",
                    json={
                        "deletes": [
                            {
                                "tuple_key": {
                                    "user": tuple["user"],
                                    "relation": tuple["relation"],
                                    "object": tuple["object"]
                                }
                            }
                            for tuple in tuples
                        ],
                        "authorization_model_id": self.auth_model_id
                    }
                )
                
                return response.status_code == 200
                
        except Exception as e:
            logger.error(f"OpenFGA delete error: {e}")
            return False
    
    async def create_store(self, name: str) -> Optional[str]:
        """Create a new OpenFGA store"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.api_url}/stores",
                    json={"name": name}
                )
                
                if response.status_code == 201:
                    result = response.json()
                    return result.get("id")
                else:
                    logger.error(f"Failed to create store: {response.status_code} - {response.text}")
                    return None
                    
        except Exception as e:
            logger.error(f"Create store error: {e}")
            return None
    
    async def write_authorization_model(self, model: Dict[str, Any]) -> Optional[str]:
        """Write an authorization model to OpenFGA"""
        if not self.store_id:
            logger.error("Store ID required to write authorization model")
            return None
            
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.api_url}/stores/{self.store_id}/authorization-models",
                    json=model
                )
                
                if response.status_code == 201:
                    result = response.json()
                    return result.get("authorization_model_id")
                else:
                    logger.error(f"Failed to write authorization model: {response.status_code} - {response.text}")
                    return None
                    
        except Exception as e:
            logger.error(f"Write authorization model error: {e}")
            return None

def format_user(user_id: str, user_type: str = "user") -> str:
    """Format user identifier for OpenFGA"""
    return f"{user_type}:{user_id}"

def format_object(object_id: str, object_type: str) -> str:
    """Format object identifier for OpenFGA"""
    return f"{object_type}:{object_id}"