import { Request, Response, NextFunction } from 'express';
import { openFGAService, OpenFGAService } from '../services/openfga';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    role: string;
    email: string;
  };
}

/**
 * Authorization middleware that integrates with OpenFGA
 */
export async function authorizationMiddleware(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    // Extract user from request (in a real app, this would come from JWT or session)
    const userId = req.headers['x-user-id'] as string;
    const userRole = req.headers['x-user-role'] as string || 'customer';
    
    if (!userId) {
      res.status(401).json({
        error: 'Unauthorized',
        message: 'User ID required in x-user-id header'
      });
      return;
    }

    // Set user info on request
    req.user = {
      id: userId,
      role: userRole,
      email: req.headers['x-user-email'] as string || `${userId}@example.com`
    };

    // Skip authorization for certain endpoints
    if (shouldSkipAuthorization(req)) {
      next();
      return;
    }

    // Determine required permission based on HTTP method and route
    const permission = getRequiredPermission(req.method, req.route?.path || req.path);
    if (!permission) {
      next();
      return;
    }

    // Extract resource identifier from request
    const resourceId = extractResourceId(req);
    if (!resourceId) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'Resource identifier required for authorization'
      });
      return;
    }

    // Check authorization with OpenFGA
    const user = OpenFGAService.formatUser(userId);
    const object = OpenFGAService.formatObject(resourceId.id, resourceId.type);
    
    const isAuthorized = await openFGAService.check(user, permission.relation, object);

    if (!isAuthorized) {
      res.status(403).json({
        error: 'Forbidden',
        message: `Insufficient permissions to ${permission.action} ${resourceId.type} ${resourceId.id}`
      });
      return;
    }

    next();
  } catch (error) {
    console.error('Authorization middleware error:', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authorization check failed'
    });
  }
}

/**
 * Determine if authorization should be skipped for this request
 */
function shouldSkipAuthorization(req: Request): boolean {
  const skipPaths = [
    '/health',
    '/api/users/profile', // Allow users to view their own profile
    '/api/users/signup',  // Allow user registration
    '/api/users/login'    // Allow user login
  ];

  return skipPaths.some(path => req.path.startsWith(path)) || req.method === 'OPTIONS';
}

/**
 * Get the required permission based on HTTP method and route
 */
function getRequiredPermission(method: string, path: string): { relation: string; action: string } | null {
  // Account permissions
  if (path.includes('/accounts')) {
    switch (method) {
      case 'GET':
        return { relation: 'viewer', action: 'view' };
      case 'POST':
      case 'PUT':
      case 'PATCH':
        return { relation: 'editor', action: 'edit' };
      case 'DELETE':
        return { relation: 'owner', action: 'delete' };
      default:
        return null;
    }
  }

  // Transaction permissions
  if (path.includes('/transactions')) {
    switch (method) {
      case 'GET':
        return { relation: 'viewer', action: 'view' };
      case 'POST':
        return { relation: 'editor', action: 'create' };
      case 'PUT':
      case 'PATCH':
        return { relation: 'editor', action: 'edit' };
      default:
        return null;
    }
  }

  // Loan permissions
  if (path.includes('/loans')) {
    switch (method) {
      case 'GET':
        return { relation: 'viewer', action: 'view' };
      case 'POST':
        return { relation: 'editor', action: 'create' };
      case 'PUT':
      case 'PATCH':
        return { relation: 'editor', action: 'edit' };
      default:
        return null;
    }
  }

  return null;
}

/**
 * Extract resource identifier from request
 */
function extractResourceId(req: Request): { type: string; id: string } | null {
  const path = req.route?.path || req.path;
  
  // Extract from URL parameters
  if (req.params.id) {
    if (path.includes('/accounts')) {
      return { type: 'account', id: req.params.id };
    }
    if (path.includes('/transactions')) {
      return { type: 'transaction', id: req.params.id };
    }
    if (path.includes('/loans')) {
      return { type: 'loan', id: req.params.id };
    }
  }

  // Extract from request body for POST requests
  if (req.method === 'POST' && req.body) {
    if (path.includes('/accounts') && req.body.accountId) {
      return { type: 'account', id: req.body.accountId };
    }
    if (path.includes('/transactions') && req.body.accountId) {
      return { type: 'account', id: req.body.accountId };
    }
    if (path.includes('/loans') && req.body.loanId) {
      return { type: 'loan', id: req.body.loanId };
    }
  }

  // For list operations, allow if user has bank-level permissions
  if (req.method === 'GET' && !req.params.id) {
    return { type: 'bank', id: 'demo-bank' };
  }

  return null;
}