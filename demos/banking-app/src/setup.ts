import { OpenFGAService, openFGAService } from './services/openfga';
import * as fs from 'fs';
import * as path from 'path';

async function setupDemo() {
  console.log('🏦 Setting up Banking Demo with OpenFGA...');

  try {
    // 1. Create OpenFGA Store
    console.log('📊 Creating OpenFGA store...');
    const storeId = await openFGAService.createStore('banking-demo');
    if (!storeId) {
      throw new Error('Failed to create OpenFGA store');
    }
    console.log(`✅ Store created with ID: ${storeId}`);

    // 2. Load and write authorization model
    console.log('📋 Writing authorization model...');
    const modelPath = path.join(__dirname, '../models/banking-authorization-model.json');
    const modelData = JSON.parse(fs.readFileSync(modelPath, 'utf8'));
    
    const authModelId = await openFGAService.writeAuthorizationModel(modelData);
    if (!authModelId) {
      throw new Error('Failed to write authorization model');
    }
    console.log(`✅ Authorization model written with ID: ${authModelId}`);

    // 3. Set up demo data
    console.log('👥 Setting up demo users...');
    await setupDemoUsers();

    console.log('🏢 Setting up demo bank structure...');
    await setupBankStructure();

    console.log('💰 Setting up demo accounts...');
    await setupDemoAccounts();

    console.log('💸 Setting up demo loans...');
    await setupDemoLoans();

    // 4. Display connection info
    console.log('\n🎉 Demo setup complete!');
    console.log('\n📝 Environment variables to set:');
    console.log(`OPENFGA_STORE_ID=${storeId}`);
    console.log(`OPENFGA_AUTH_MODEL_ID=${authModelId}`);
    console.log(`OPENFGA_API_URL=${process.env.OPENFGA_API_URL || 'http://localhost:8080'}`);

    console.log('\n🔧 Demo users created:');
    console.log('- alice (customer)');
    console.log('- bob (customer)');
    console.log('- charlie (teller)');
    console.log('- diana (manager)');
    console.log('- eve (loan_officer)');
    console.log('- frank (admin)');

    console.log('\n📚 API Examples:');
    console.log('# Create account:');
    console.log('curl -X POST http://localhost:3000/api/accounts \\');
    console.log('  -H "x-user-id: alice" \\');
    console.log('  -H "Content-Type: application/json" \\');
    console.log('  -d \'{"accountNumber": "12345678", "accountType": "checking", "initialBalance": 1000}\'');

    console.log('\n# Transfer money:');
    console.log('curl -X POST http://localhost:3000/api/transactions \\');
    console.log('  -H "x-user-id: alice" \\');
    console.log('  -H "Content-Type: application/json" \\');
    console.log('  -d \'{"fromAccountId": "acc_12345678", "toAccountId": "acc_87654321", "amount": 100}\'');

  } catch (error) {
    console.error('❌ Setup failed:', error);
    process.exit(1);
  }
}

async function setupDemoUsers() {
  const users = [
    { id: 'alice', role: 'customer', branch: 'branch_main' },
    { id: 'bob', role: 'customer', branch: 'branch_main' },
    { id: 'charlie', role: 'teller', branch: 'branch_main' },
    { id: 'diana', role: 'manager', branch: 'branch_main' },
    { id: 'eve', role: 'loan_officer', branch: 'branch_main' },
    { id: 'frank', role: 'admin', branch: 'branch_main' }
  ];

  const tuples = [];

  for (const user of users) {
    const userObj = OpenFGAService.formatUser(user.id);
    const bankObj = OpenFGAService.formatObject('demo-bank', 'bank');
    const branchObj = OpenFGAService.formatObject(user.branch, 'branch');

    switch (user.role) {
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
  }

  await openFGAService.writeTuples(tuples);
  console.log(`✅ Created ${users.length} demo users`);
}

async function setupBankStructure() {
  const bankObj = OpenFGAService.formatObject('demo-bank', 'bank');
  const branchObj = OpenFGAService.formatObject('branch_main', 'branch');

  const tuples = [
    { user: bankObj, relation: 'bank', object: branchObj }
  ];

  await openFGAService.writeTuples(tuples);
  console.log('✅ Bank structure created');
}

async function setupDemoAccounts() {
  const accounts = [
    { id: 'acc_alice_checking', owner: 'alice', type: 'checking' },
    { id: 'acc_alice_savings', owner: 'alice', type: 'savings' },
    { id: 'acc_bob_checking', owner: 'bob', type: 'checking' },
    { id: 'acc_shared', owner: 'alice', coOwner: 'bob', type: 'joint' }
  ];

  const tuples = [];

  for (const account of accounts) {
    const accountObj = OpenFGAService.formatObject(account.id, 'account');
    const bankObj = OpenFGAService.formatObject('demo-bank', 'bank');
    const branchObj = OpenFGAService.formatObject('branch_main', 'branch');
    const ownerObj = OpenFGAService.formatUser(account.owner);

    tuples.push(
      { user: ownerObj, relation: 'owner', object: accountObj },
      { user: bankObj, relation: 'bank', object: accountObj },
      { user: branchObj, relation: 'branch', object: accountObj }
    );

    if (account.coOwner) {
      const coOwnerObj = OpenFGAService.formatUser(account.coOwner);
      tuples.push({ user: coOwnerObj, relation: 'co_owner', object: accountObj });
    }
  }

  await openFGAService.writeTuples(tuples);
  console.log(`✅ Created ${accounts.length} demo accounts`);
}

async function setupDemoLoans() {
  const loans = [
    { id: 'loan_alice_auto', borrower: 'alice', officer: 'eve' },
    { id: 'loan_bob_home', borrower: 'bob', coBorrower: 'alice', officer: 'eve' }
  ];

  const tuples = [];

  for (const loan of loans) {
    const loanObj = OpenFGAService.formatObject(loan.id, 'loan');
    const bankObj = OpenFGAService.formatObject('demo-bank', 'bank');
    const borrowerObj = OpenFGAService.formatUser(loan.borrower);
    const officerObj = OpenFGAService.formatUser(loan.officer);

    tuples.push(
      { user: borrowerObj, relation: 'borrower', object: loanObj },
      { user: officerObj, relation: 'loan_officer', object: loanObj },
      { user: bankObj, relation: 'bank', object: loanObj }
    );

    if (loan.coBorrower) {
      const coBorrowerObj = OpenFGAService.formatUser(loan.coBorrower);
      tuples.push({ user: coBorrowerObj, relation: 'co_borrower', object: loanObj });
    }
  }

  await openFGAService.writeTuples(tuples);
  console.log(`✅ Created ${loans.length} demo loans`);
}

// Run setup if this script is executed directly
if (require.main === module) {
  setupDemo().catch(console.error);
}

export { setupDemo };