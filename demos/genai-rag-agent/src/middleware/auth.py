from typing import Optional
from fastapi import HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import logging

from src.models.schemas import UserInfo

logger = logging.getLogger(__name__)

# Security scheme for FastAPI
security = HTTPBearer(auto_error=False)

class AuthMiddleware:
    """Authentication middleware for the GenAI RAG agent"""
    
    def __init__(self):
        # In production, use proper JWT validation
        # For demo, we'll use simple header-based auth
        pass
    
    async def get_user_from_token(self, token: str) -> Optional[UserInfo]:
        """Extract user information from token"""
        # In production, validate JWT token and extract user info
        # For demo, accept any token and extract user from request headers
        
        # Mock user extraction - in production, decode and validate JWT
        if token.startswith("demo_"):
            user_id = token.replace("demo_", "")
            return UserInfo(
                user_id=user_id,
                email=f"{user_id}@example.com",
                role="user"
            )
        
        return None
    
    async def get_user_from_headers(self, request: Request) -> Optional[UserInfo]:
        """Extract user information from request headers (demo mode)"""
        user_id = request.headers.get("x-user-id")
        user_email = request.headers.get("x-user-email")
        user_role = request.headers.get("x-user-role", "user")
        
        if user_id:
            return UserInfo(
                user_id=user_id,
                email=user_email or f"{user_id}@example.com",
                role=user_role
            )
        
        return None

# Global auth middleware instance
auth_middleware = AuthMiddleware()

async def get_current_user(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> UserInfo:
    """Get current user from request"""
    user = None
    
    # Try to get user from Authorization header
    if credentials:
        user = await auth_middleware.get_user_from_token(credentials.credentials)
    
    # Fallback to demo headers for development
    if not user:
        user = await auth_middleware.get_user_from_headers(request)
    
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Authentication required. Provide either Authorization header or x-user-id header.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    return user

# Optional authentication for endpoints that work with or without auth
async def get_current_user_optional(
    request: Request,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Optional[UserInfo]:
    """Get current user from request, returns None if not authenticated"""
    try:
        return await get_current_user(request, credentials)
    except HTTPException:
        return None