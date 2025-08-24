import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/authorization';
import { openFGAService, OpenFGAService } from '../services/openfga';
import { v4 as uuidv4 } from 'uuid';

const router = Router();

// Mock database for demo purposes
const loans = new Map<string, any>();

/**
 * Get loans accessible to the user
 */
router.get('/', async (req: AuthenticatedRequest, res) => {
  try {
    const userId = req.user!.id;
    const user = OpenFGAService.formatUser(userId);

    // Get loans the user can view
    const accessibleLoans = await openFGAService.listObjects(user, 'viewer', 'loan');
    
    const userLoans = accessibleLoans
      .map(loanObj => {
        const loanId = loanObj.replace('loan:', '');
        return loans.get(loanId);
      })
      .filter(Boolean)
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    res.json({
      loans: userLoans,
      total: userLoans.length
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve loans' });
  }
});

/**
 * Get specific loan details
 */
router.get('/:id', async (req: AuthenticatedRequest, res) => {
  try {
    const loanId = req.params.id;
    const loan = loans.get(loanId);

    if (!loan) {
      return res.status(404).json({ error: 'Loan not found' });
    }

    res.json(loan);
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve loan' });
  }
});

/**
 * Apply for a new loan
 */
router.post('/', async (req: AuthenticatedRequest, res) => {
  try {
    const { 
      loanType,
      principalAmount,
      termMonths,
      purpose,
      collateral,
      coBorrowerId
    } = req.body;
    const userId = req.user!.id;

    if (!loanType || !principalAmount || !termMonths) {
      return res.status(400).json({ 
        error: 'Missing required fields: loanType, principalAmount, termMonths' 
      });
    }

    if (principalAmount <= 0 || termMonths <= 0) {
      return res.status(400).json({ 
        error: 'Principal amount and term must be positive' 
      });
    }

    const loanId = `loan_${uuidv4()}`;
    
    // Calculate simple interest rate based on loan type
    const interestRate = calculateInterestRate(loanType, principalAmount);
    const monthlyPayment = calculateMonthlyPayment(principalAmount, interestRate, termMonths);

    const loan = {
      id: loanId,
      loanType,
      principalAmount,
      termMonths,
      interestRate,
      monthlyPayment,
      purpose: purpose || 'General purpose',
      collateral,
      borrowerId: userId,
      coBorrowerId,
      status: 'pending_review',
      applicationDate: new Date().toISOString(),
      createdAt: new Date().toISOString(),
      remainingBalance: principalAmount,
      nextPaymentDate: calculateNextPaymentDate()
    };

    loans.set(loanId, loan);

    // Set up OpenFGA relationships
    const borrower = OpenFGAService.formatUser(userId);
    const loanObj = OpenFGAService.formatObject(loanId, 'loan');
    const bankObj = OpenFGAService.formatObject('demo-bank', 'bank');

    const tuples = [
      { user: borrower, relation: 'borrower', object: loanObj },
      { user: bankObj, relation: 'bank', object: loanObj }
    ];

    // Add co-borrower if specified
    if (coBorrowerId) {
      const coBorrower = OpenFGAService.formatUser(coBorrowerId);
      tuples.push({ user: coBorrower, relation: 'co_borrower', object: loanObj });
    }

    await openFGAService.writeTuples(tuples);

    res.status(201).json(loan);
  } catch (error) {
    console.error('Failed to create loan application:', error);
    res.status(500).json({ error: 'Failed to create loan application' });
  }
});

/**
 * Update loan status (for loan officers)
 */
router.patch('/:id/status', async (req: AuthenticatedRequest, res) => {
  try {
    const loanId = req.params.id;
    const { status, reviewNotes, loanOfficerId } = req.body;
    const userId = req.user!.id;

    const loan = loans.get(loanId);
    if (!loan) {
      return res.status(404).json({ error: 'Loan not found' });
    }

    const validStatuses = [
      'pending_review', 
      'under_review', 
      'approved', 
      'rejected', 
      'disbursed', 
      'closed'
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ 
        error: `Invalid status. Must be one of: ${validStatuses.join(', ')}` 
      });
    }

    // Update loan
    loan.status = status;
    loan.reviewNotes = reviewNotes;
    loan.reviewedBy = userId;
    loan.reviewedAt = new Date().toISOString();
    loan.updatedAt = new Date().toISOString();

    // If approved, set loan officer
    if (status === 'approved' && loanOfficerId) {
      loan.loanOfficerId = loanOfficerId;
      
      // Add loan officer relationship in OpenFGA
      const loanOfficer = OpenFGAService.formatUser(loanOfficerId);
      const loanObj = OpenFGAService.formatObject(loanId, 'loan');
      
      await openFGAService.writeTuples([
        { user: loanOfficer, relation: 'loan_officer', object: loanObj }
      ]);
    }

    loans.set(loanId, loan);

    res.json(loan);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update loan status' });
  }
});

/**
 * Make a loan payment
 */
router.post('/:id/payments', async (req: AuthenticatedRequest, res) => {
  try {
    const loanId = req.params.id;
    const { amount, paymentType = 'regular' } = req.body;
    const userId = req.user!.id;

    const loan = loans.get(loanId);
    if (!loan) {
      return res.status(404).json({ error: 'Loan not found' });
    }

    if (loan.status !== 'disbursed') {
      return res.status(400).json({ 
        error: 'Payments can only be made on disbursed loans' 
      });
    }

    if (amount <= 0) {
      return res.status(400).json({ error: 'Payment amount must be positive' });
    }

    if (amount > loan.remainingBalance) {
      return res.status(400).json({ 
        error: 'Payment amount cannot exceed remaining balance' 
      });
    }

    const paymentId = `pay_${uuidv4()}`;
    const payment = {
      id: paymentId,
      loanId,
      amount,
      paymentType,
      paidBy: userId,
      paymentDate: new Date().toISOString(),
      status: 'completed'
    };

    // Update loan balance
    loan.remainingBalance -= amount;
    loan.lastPaymentDate = new Date().toISOString();
    loan.nextPaymentDate = calculateNextPaymentDate();
    loan.updatedAt = new Date().toISOString();

    // Mark as closed if fully paid
    if (loan.remainingBalance <= 0) {
      loan.status = 'closed';
      loan.closedDate = new Date().toISOString();
    }

    // In a real system, payments would be stored separately
    if (!loan.payments) {
      loan.payments = [];
    }
    loan.payments.push(payment);

    loans.set(loanId, loan);

    res.status(201).json({
      payment,
      loan: {
        id: loanId,
        remainingBalance: loan.remainingBalance,
        status: loan.status,
        nextPaymentDate: loan.nextPaymentDate
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to process payment' });
  }
});

/**
 * Get loan payment history
 */
router.get('/:id/payments', async (req: AuthenticatedRequest, res) => {
  try {
    const loanId = req.params.id;
    const loan = loans.get(loanId);

    if (!loan) {
      return res.status(404).json({ error: 'Loan not found' });
    }

    res.json({
      loanId,
      payments: loan.payments || [],
      totalPaid: loan.principalAmount - loan.remainingBalance,
      remainingBalance: loan.remainingBalance
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve payment history' });
  }
});

/**
 * Calculate interest rate based on loan type and amount
 */
function calculateInterestRate(loanType: string, amount: number): number {
  const baseRates = {
    'personal': 8.5,
    'auto': 4.5,
    'home': 3.5,
    'business': 6.0
  };

  let rate = baseRates[loanType as keyof typeof baseRates] || 7.0;

  // Adjust rate based on amount (larger loans get better rates)
  if (amount > 100000) rate -= 0.5;
  if (amount > 500000) rate -= 0.5;

  return rate;
}

/**
 * Calculate monthly payment using simple formula
 */
function calculateMonthlyPayment(principal: number, annualRate: number, months: number): number {
  const monthlyRate = annualRate / 100 / 12;
  const payment = principal * (monthlyRate * Math.pow(1 + monthlyRate, months)) / 
                  (Math.pow(1 + monthlyRate, months) - 1);
  return Math.round(payment * 100) / 100;
}

/**
 * Calculate next payment date (1st of next month)
 */
function calculateNextPaymentDate(): string {
  const nextMonth = new Date();
  nextMonth.setMonth(nextMonth.getMonth() + 1);
  nextMonth.setDate(1);
  return nextMonth.toISOString().split('T')[0];
}

export default router;