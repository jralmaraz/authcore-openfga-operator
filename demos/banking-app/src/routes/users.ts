import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/authorization';
import { openFGAService, OpenFGAService } from '../services/openfga';

const router = Router();

// Mock user database for demo purposes
const users = new Map<string, any>();

/**
 * Get user profile (no authorization needed - users can view their own profile)
 */
router.get('/profile', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const user = users.get(userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Remove sensitive information
    const { password, ...publicProfile } = user;

    res.json(publicProfile);
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve profile' });
  }
});

/**
 * Update user profile
 */
router.patch('/profile', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const user = users.get(userId);

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const allowedUpdates = ['firstName', 'lastName', 'email', 'phone', 'address'];
    const updates = Object.keys(req.body)
      .filter(key => allowedUpdates.includes(key))
      .reduce((obj, key) => {
        obj[key] = req.body[key];
        return obj;
      }, {} as any);

    const updatedUser = { 
      ...user, 
      ...updates, 
      updatedAt: new Date().toISOString() 
    };

    users.set(userId, updatedUser);

    // Remove sensitive information
    const { password, ...publicProfile } = updatedUser;

    res.json(publicProfile);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

/**
 * User registration (no authorization needed)
 */
router.post('/signup', async (req: AuthenticatedRequest, res) => {
  try {
    const { 
      userId, 
      firstName, 
      lastName, 
      email, 
      role = 'customer',
      branchId = 'branch_main'
    } = req.body;

    if (!userId || !firstName || !lastName || !email) {
      return res.status(400).json({ 
        error: 'Missing required fields: userId, firstName, lastName, email' 
      });
    }

    if (users.has(userId)) {
      return res.status(409).json({ error: 'User already exists' });
    }

    const user = {
      id: userId,
      firstName,
      lastName,
      email,
      role,
      branchId,
      status: 'active',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    users.set(userId, user);

    // Set up OpenFGA relationships based on role
    const userObj = OpenFGAService.formatUser(userId);
    const bankObj = OpenFGAService.formatObject('demo-bank', 'bank');
    const branchObj = OpenFGAService.formatObject(branchId, 'branch');

    const tuples = [];

    switch (role) {
      case 'admin':
        tuples.push({ user: userObj, relation: 'admin', object: bankObj });
        break;
      case 'manager':
        tuples.push(
          { user: userObj, relation: 'employee', object: bankObj },
          { user: userObj, relation: 'manager', object: branchObj }
        );
        break;
      case 'teller':
        tuples.push(
          { user: userObj, relation: 'employee', object: bankObj },
          { user: userObj, relation: 'teller', object: branchObj }
        );
        break;
      case 'loan_officer':
        tuples.push({ user: userObj, relation: 'employee', object: bankObj });
        break;
      case 'customer':
      default:
        tuples.push({ user: userObj, relation: 'customer', object: bankObj });
        break;
    }

    if (tuples.length > 0) {
      await openFGAService.writeTuples(tuples);
    }

    // Remove sensitive information
    const { password, ...publicProfile } = user;

    res.status(201).json(publicProfile);
  } catch (error) {
    console.error('Failed to create user:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

/**
 * Get user permissions and roles
 */
router.get('/permissions', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const user = OpenFGAService.formatUser(userId);

    // Check various permissions
    const permissions = {
      bank: {
        admin: await openFGAService.check(user, 'admin', 'bank:demo-bank'),
        employee: await openFGAService.check(user, 'employee', 'bank:demo-bank'),
        customer: await openFGAService.check(user, 'customer', 'bank:demo-bank'),
        viewer: await openFGAService.check(user, 'viewer', 'bank:demo-bank')
      },
      branch: {
        manager: await openFGAService.check(user, 'manager', 'branch:branch_main'),
        teller: await openFGAService.check(user, 'teller', 'branch:branch_main'),
        viewer: await openFGAService.check(user, 'viewer', 'branch:branch_main')
      }
    };

    // Get accessible accounts
    const accessibleAccounts = await openFGAService.listObjects(user, 'viewer', 'account');
    const ownedAccounts = await openFGAService.listObjects(user, 'owner', 'account');

    // Get accessible loans
    const accessibleLoans = await openFGAService.listObjects(user, 'viewer', 'loan');

    res.json({
      userId,
      permissions,
      resources: {
        accounts: {
          viewable: accessibleAccounts.length,
          owned: ownedAccounts.length
        },
        loans: {
          viewable: accessibleLoans.length
        }
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve permissions' });
  }
});

/**
 * Get all users (admin only)
 */
router.get('/', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const user = OpenFGAService.formatUser(userId);

    // Check if user is admin
    const isAdmin = await openFGAService.check(user, 'admin', 'bank:demo-bank');
    
    if (!isAdmin) {
      return res.status(403).json({ 
        error: 'Forbidden', 
        message: 'Admin access required' 
      });
    }

    const allUsers = Array.from(users.values()).map(u => {
      const { password, ...publicProfile } = u;
      return publicProfile;
    });

    res.json({
      users: allUsers,
      total: allUsers.length
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve users' });
  }
});

/**
 * Update user role (admin only)
 */
router.patch('/:targetUserId/role', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const targetUserId = req.params.targetUserId;
    const { role, branchId } = req.body;
    const user = OpenFGAService.formatUser(userId);

    // Check if user is admin
    const isAdmin = await openFGAService.check(user, 'admin', 'bank:demo-bank');
    
    if (!isAdmin) {
      return res.status(403).json({ 
        error: 'Forbidden', 
        message: 'Admin access required' 
      });
    }

    const targetUser = users.get(targetUserId);
    if (!targetUser) {
      return res.status(404).json({ error: 'User not found' });
    }

    const validRoles = ['customer', 'teller', 'manager', 'loan_officer', 'admin'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({ 
        error: `Invalid role. Must be one of: ${validRoles.join(', ')}` 
      });
    }

    // Update user
    const oldRole = targetUser.role;
    targetUser.role = role;
    if (branchId) targetUser.branchId = branchId;
    targetUser.updatedAt = new Date().toISOString();
    targetUser.roleChangedBy = userId;

    users.set(targetUserId, targetUser);

    // TODO: Update OpenFGA relationships based on role change
    // This would involve removing old relationships and adding new ones

    res.json({
      message: 'User role updated successfully',
      userId: targetUserId,
      oldRole,
      newRole: role,
      updatedBy: userId
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update user role' });
  }
});

export default router;