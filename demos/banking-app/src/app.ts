import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { authorizationMiddleware } from './middleware/authorization';
import { errorHandler } from './middleware/errorHandler';
import accountRoutes from './routes/accounts';
import transactionRoutes from './routes/transactions';
import loanRoutes from './routes/loans';
import userRoutes from './routes/users';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));

// Logging
app.use(morgan('combined'));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'banking-demo',
    version: '1.0.0'
  });
});

// API routes with authorization middleware
app.use('/api/accounts', authorizationMiddleware, accountRoutes);
app.use('/api/transactions', authorizationMiddleware, transactionRoutes);
app.use('/api/loans', authorizationMiddleware, loanRoutes);
app.use('/api/users', userRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Banking Demo API with OpenFGA Authorization',
    documentation: '/api/docs',
    health: '/health',
    endpoints: {
      accounts: '/api/accounts',
      transactions: '/api/transactions', 
      loans: '/api/loans',
      users: '/api/users'
    }
  });
});

// Error handling
app.use(errorHandler);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    timestamp: new Date().toISOString()
  });
});

const server = app.listen(PORT, () => {
  console.log(`🏦 Banking Demo Server running on port ${PORT}`);
  console.log(`🔐 OpenFGA Authorization enabled`);
  console.log(`🔗 OpenFGA API URL: ${process.env.OPENFGA_API_URL || 'http://localhost:8080'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});

export default app;