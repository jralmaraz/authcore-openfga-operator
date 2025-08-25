# Banking Application OpenFGA Configuration Example

This file shows how to set up and use the Banking Application OpenFGA authorization model.

## 1. Store Creation

First, create an OpenFGA store and import the authorization model:

```bash
# Create store
curl -X POST http://localhost:8080/stores \
  -H "Content-Type: application/json" \
  -d '{
    "name": "banking-app-demo"
  }'

# Import authorization model (save the model_id from response)
curl -X POST http://localhost:8080/stores/{store_id}/authorization-models \
  -H "Content-Type: application/json" \
  -d @authorization-model.json
```

## 2. Write Relationship Tuples

Add the relationship tuples to establish permissions:

```bash
# Bank admin relationship
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "user:frank",
          "relation": "admin",
          "object": "bank:bank1"
        }
      ]
    }
  }'

# Branch relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "bank:bank1",
          "relation": "parent_bank",
          "object": "branch:branch1"
        },
        {
          "user": "user:diana",
          "relation": "manager",
          "object": "branch:branch1"
        },
        {
          "user": "user:charlie",
          "relation": "teller",
          "object": "branch:branch1"
        }
      ]
    }
  }'

# Account relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "branch:branch1",
          "relation": "parent_branch",
          "object": "account:acc1"
        },
        {
          "user": "user:alice",
          "relation": "owner",
          "object": "account:acc1"
        },
        {
          "user": "user:alice",
          "relation": "co_owner",
          "object": "account:acc2"
        },
        {
          "user": "user:bob",
          "relation": "owner",
          "object": "account:acc2"
        }
      ]
    }
  }'

# Loan relationships
curl -X POST http://localhost:8080/stores/{store_id}/write \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {
          "user": "branch:branch1",
          "relation": "parent_branch",
          "object": "loan:loan1"
        },
        {
          "user": "user:alice",
          "relation": "borrower",
          "object": "loan:loan1"
        },
        {
          "user": "user:bob",
          "relation": "co_borrower",
          "object": "loan:loan1"
        },
        {
          "user": "user:eve",
          "relation": "loan_officer",
          "object": "loan:loan1"
        }
      ]
    }
  }'
```

## 3. Check Authorization

Now you can check permissions using the Check API:

```bash
# Check if Alice can view her account
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:alice",
      "relation": "can_view",
      "object": "account:acc1"
    }
  }'
# Expected: {"allowed": true}

# Check if Charlie (teller) can deposit to account
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:charlie",
      "relation": "can_deposit",
      "object": "account:acc1"
    }
  }'
# Expected: {"allowed": true}

# Check if Eve (loan officer) can approve loan
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:eve",
      "relation": "can_approve",
      "object": "loan:loan1"
    }
  }'
# Expected: {"allowed": true}

# Check if unauthorized user can withdraw
curl -X POST http://localhost:8080/stores/{store_id}/check \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:eve",
      "relation": "can_withdraw",
      "object": "account:acc1"
    }
  }'
# Expected: {"allowed": false}
```

## 4. Expand Relationships

You can also expand relationships to see who has access:

```bash
# See who can view account:acc1
curl -X POST http://localhost:8080/stores/{store_id}/expand \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "relation": "can_view",
      "object": "account:acc1"
    }
  }'

# See who can approve loans
curl -X POST http://localhost:8080/stores/{store_id}/expand \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "relation": "can_approve",
      "object": "loan:loan1"
    }
  }'
```

## 5. List Objects

Find all objects a user can access:

```bash
# Find all accounts Alice can view
curl -X POST http://localhost:8080/stores/{store_id}/list-objects \
  -H "Content-Type: application/json" \
  -d '{
    "user": "user:alice",
    "relation": "can_view",
    "type": "account"
  }'

# Find all loans Eve can approve
curl -X POST http://localhost:8080/stores/{store_id}/list-objects \
  -H "Content-Type: application/json" \
  -d '{
    "user": "user:eve",
    "relation": "can_approve",
    "type": "loan"
  }'
```

## Integration Example

Here's how you might integrate this into a banking application:

```javascript
// Banking API middleware
async function checkBankingPermission(req, res, next) {
  const { user, action, resource } = req.auth;
  
  const response = await fetch(`${OPENFGA_URL}/stores/${STORE_ID}/check`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      tuple_key: {
        user: `user:${user}`,
        relation: action, // e.g., 'can_view', 'can_withdraw'
        object: resource  // e.g., 'account:acc1'
      }
    })
  });
  
  const result = await response.json();
  
  if (result.allowed) {
    next();
  } else {
    res.status(403).json({ error: 'Insufficient permissions' });
  }
}

// Usage in Express.js
app.get('/accounts/:id', checkBankingPermission, (req, res) => {
  // Return account details
});

app.post('/accounts/:id/withdraw', checkBankingPermission, (req, res) => {
  // Process withdrawal
});
```