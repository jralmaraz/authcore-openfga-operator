import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/authorization';
import { openFGAService, OpenFGAService } from '../services/openfga';

const router = Router();

// Mock database for demo purposes
const accounts = new Map<string, any>();

/**
 * Get all accounts accessible to the user
 */
router.get('/', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const user = OpenFGAService.formatUser(userId);

    // Get accounts the user can view
    const accessibleAccounts = await openFGAService.listObjects(user, 'viewer', 'account');
    
    const userAccounts = accessibleAccounts
      .map(accountObj => {
        const accountId = accountObj.replace('account:', '');
        return accounts.get(accountId);
      })
      .filter(Boolean);

    res.json({
      accounts: userAccounts,
      total: userAccounts.length
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve accounts' });
  }
});

/**
 * Get specific account details
 */
router.get('/:id', async (req: AuthenticatedRequest, res) => {
  try {
    const accountId = req.params.id;
    const account = accounts.get(accountId);

    if (!account) {
      return res.status(404).json({ error: 'Account not found' });
    }

    res.json(account);
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve account' });
  }
});

/**
 * Create new account
 */
router.post('/', async (req: AuthenticatedRequest, res) => {
  try {
    const { accountNumber, accountType, initialBalance = 0, branchId } = req.body;
    const userId = req.user!.id;

    if (!accountNumber || !accountType) {
      return res.status(400).json({ 
        error: 'Missing required fields: accountNumber, accountType' 
      });
    }

    const accountId = `acc_${accountNumber}`;
    
    if (accounts.has(accountId)) {
      return res.status(409).json({ error: 'Account already exists' });
    }

    const account = {
      id: accountId,
      accountNumber,
      accountType,
      balance: initialBalance,
      ownerId: userId,
      branchId: branchId || 'branch_main',
      createdAt: new Date().toISOString(),
      status: 'active'
    };

    accounts.set(accountId, account);

    // Set up OpenFGA relationships
    const user = OpenFGAService.formatUser(userId);
    const accountObj = OpenFGAService.formatObject(accountId, 'account');
    const bankObj = OpenFGAService.formatObject('demo-bank', 'bank');
    const branchObj = OpenFGAService.formatObject(branchId || 'branch_main', 'branch');

    await openFGAService.writeTuples([
      { user, relation: 'owner', object: accountObj },
      { user: bankObj, relation: 'bank', object: accountObj },
      { user: branchObj, relation: 'branch', object: accountObj }
    ]);

    res.status(201).json(account);
  } catch (error) {
    console.error('Failed to create account:', error);
    res.status(500).json({ error: 'Failed to create account' });
  }
});

/**
 * Update account details
 */
router.patch('/:id', async (req: AuthenticatedRequest, res) => {
  try {
    const accountId = req.params.id;
    const account = accounts.get(accountId);

    if (!account) {
      return res.status(404).json({ error: 'Account not found' });
    }

    const updates = req.body;
    const updatedAccount = { ...account, ...updates, updatedAt: new Date().toISOString() };
    
    accounts.set(accountId, updatedAccount);

    res.json(updatedAccount);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update account' });
  }
});

/**
 * Get account balance
 */
router.get('/:id/balance', async (req: AuthenticatedRequest, res) => {
  try {
    const accountId = req.params.id;
    const account = accounts.get(accountId);

    if (!account) {
      return res.status(404).json({ error: 'Account not found' });
    }

    res.json({
      accountId,
      balance: account.balance,
      currency: account.currency || 'USD',
      asOf: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve balance' });
  }
});

/**
 * Add authorized user to account
 */
router.post('/:id/authorized-users', async (req: AuthenticatedRequest, res) => {
  try {
    const accountId = req.params.id;
    const { userId, permissions } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'User ID required' });
    }

    const account = accounts.get(accountId);
    if (!account) {
      return res.status(404).json({ error: 'Account not found' });
    }

    // Add user as authorized user in OpenFGA
    const user = OpenFGAService.formatUser(userId);
    const accountObj = OpenFGAService.formatObject(accountId, 'account');
    const relation = permissions === 'full' ? 'co_owner' : 'authorized_user';

    await openFGAService.writeTuples([
      { user, relation, object: accountObj }
    ]);

    res.json({
      message: 'Authorized user added successfully',
      userId,
      accountId,
      permissions: relation
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to add authorized user' });
  }
});

export default router;