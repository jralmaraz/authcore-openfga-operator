import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/authorization';
import { openFGAService, OpenFGAService } from '../services/openfga';
import { v4 as uuidv4 } from 'uuid';

const router = Router();

// Mock database for demo purposes
const transactions = new Map<string, any>();
const accounts = new Map<string, any>(); // Shared with accounts route

/**
 * Get transactions for accessible accounts
 */
router.get('/', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const user = OpenFGAService.formatUser(userId);

    // Get accounts the user can view
    const accessibleAccounts = await openFGAService.listObjects(user, 'viewer', 'account');
    const accountIds = accessibleAccounts.map(acc => acc.replace('account:', ''));

    // Get transactions for these accounts
    const userTransactions = Array.from(transactions.values())
      .filter(tx => accountIds.includes(tx.fromAccountId) || accountIds.includes(tx.toAccountId))
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    res.json({
      transactions: userTransactions,
      total: userTransactions.length
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve transactions' });
  }
});

/**
 * Get specific transaction details
 */
router.get('/:id', async (req: AuthenticatedRequest, res) => {
  try {
    const transactionId = req.params.id;
    const transaction = transactions.get(transactionId);

    if (!transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    res.json(transaction);
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve transaction' });
  }
});

/**
 * Create new transaction
 */
router.post('/', async (req: AuthenticatedRequest, res) => {
  try {
    const { 
      fromAccountId, 
      toAccountId, 
      amount, 
      description, 
      transactionType = 'transfer'
    } = req.body;
    const userId = req.user!.id;

    if (!fromAccountId || !toAccountId || !amount) {
      return res.status(400).json({ 
        error: 'Missing required fields: fromAccountId, toAccountId, amount' 
      });
    }

    if (amount <= 0) {
      return res.status(400).json({ error: 'Amount must be positive' });
    }

    // Check if accounts exist
    const fromAccount = accounts.get(fromAccountId);
    const toAccount = accounts.get(toAccountId);

    if (!fromAccount || !toAccount) {
      return res.status(404).json({ error: 'One or both accounts not found' });
    }

    // Check sufficient balance
    if (fromAccount.balance < amount) {
      return res.status(400).json({ error: 'Insufficient balance' });
    }

    const transactionId = `tx_${uuidv4()}`;
    const transaction = {
      id: transactionId,
      fromAccountId,
      toAccountId,
      amount,
      description: description || 'Transfer',
      transactionType,
      status: 'pending',
      initiatorId: userId,
      createdAt: new Date().toISOString(),
      processedAt: null
    };

    transactions.set(transactionId, transaction);

    // Set up OpenFGA relationships
    const user = OpenFGAService.formatUser(userId);
    const transactionObj = OpenFGAService.formatObject(transactionId, 'transaction');
    const fromAccountObj = OpenFGAService.formatObject(fromAccountId, 'account');

    await openFGAService.writeTuples([
      { user, relation: 'initiator', object: transactionObj },
      { user: fromAccountObj, relation: 'account', object: transactionObj }
    ]);

    // In a real system, this would be processed asynchronously
    setTimeout(async () => {
      await processTransaction(transactionId);
    }, 1000);

    res.status(201).json(transaction);
  } catch (error) {
    console.error('Failed to create transaction:', error);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

/**
 * Process a transaction (mock implementation)
 */
async function processTransaction(transactionId: string): Promise<void> {
  try {
    const transaction = transactions.get(transactionId);
    if (!transaction) return;

    const fromAccount = accounts.get(transaction.fromAccountId);
    const toAccount = accounts.get(transaction.toAccountId);

    if (!fromAccount || !toAccount) {
      transaction.status = 'failed';
      transaction.failureReason = 'Account not found';
      return;
    }

    if (fromAccount.balance < transaction.amount) {
      transaction.status = 'failed';
      transaction.failureReason = 'Insufficient balance';
      return;
    }

    // Update balances
    fromAccount.balance -= transaction.amount;
    fromAccount.updatedAt = new Date().toISOString();
    
    toAccount.balance += transaction.amount;
    toAccount.updatedAt = new Date().toISOString();

    // Update transaction status
    transaction.status = 'completed';
    transaction.processedAt = new Date().toISOString();

    accounts.set(transaction.fromAccountId, fromAccount);
    accounts.set(transaction.toAccountId, toAccount);
    transactions.set(transactionId, transaction);

    console.log(`Transaction ${transactionId} processed successfully`);
  } catch (error) {
    console.error(`Failed to process transaction ${transactionId}:`, error);
    const transaction = transactions.get(transactionId);
    if (transaction) {
      transaction.status = 'failed';
      transaction.failureReason = 'Processing error';
    }
  }
}

/**
 * Get transaction status
 */
router.get('/:id/status', async (req: AuthenticatedRequest, res) => {
  try {
    const transactionId = req.params.id;
    const transaction = transactions.get(transactionId);

    if (!transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    res.json({
      id: transactionId,
      status: transaction.status,
      createdAt: transaction.createdAt,
      processedAt: transaction.processedAt,
      failureReason: transaction.failureReason
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve transaction status' });
  }
});

/**
 * Cancel a pending transaction
 */
router.patch('/:id/cancel', async (req: AuthenticatedRequest, res) => {
  try {
    const transactionId = req.params.id;
    const transaction = transactions.get(transactionId);

    if (!transaction) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    if (transaction.status !== 'pending') {
      return res.status(400).json({ 
        error: `Cannot cancel transaction with status: ${transaction.status}` 
      });
    }

    transaction.status = 'cancelled';
    transaction.cancelledAt = new Date().toISOString();
    transaction.cancelledBy = req.user!.id;

    transactions.set(transactionId, transaction);

    res.json({
      message: 'Transaction cancelled successfully',
      transaction
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to cancel transaction' });
  }
});

export default router;