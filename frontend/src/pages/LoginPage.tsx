import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import './LoginPage.css';

function LoginPage() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      await login(email, password);
    } catch (err) {
      setError('Invalid credentials. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-background">
        <div className="gradient-orb orb-1"></div>
        <div className="gradient-orb orb-2"></div>
        <div className="gradient-orb orb-3"></div>
      </div>

      <div className="login-container">
        <div className="login-card">
          <div className="login-header">
            <div className="login-logo">
              <svg width="48" height="48" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect width="48" height="48" rx="12" fill="url(#loginGradient)" />
                <path
                  d="M24 12L30 18H27V24H30L24 30L18 24H21V18H18L24 12Z"
                  fill="white"
                  opacity="0.9"
                />
                <defs>
                  <linearGradient id="loginGradient" x1="0" y1="0" x2="48" y2="48">
                    <stop stopColor="#0078d4" />
                    <stop offset="1" stopColor="#5e5ce6" />
                  </linearGradient>
                </defs>
              </svg>
            </div>
            <h1>GPT-RAG Platform</h1>
            <p>Deploy your own AI-powered knowledge base</p>
          </div>

          <form onSubmit={handleSubmit} className="login-form">
            {error && (
              <div className="login-error">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                  <path
                    d="M8 14C11.3137 14 14 11.3137 14 8C14 4.68629 11.3137 2 8 2C4.68629 2 2 4.68629 2 8C2 11.3137 4.68629 14 8 14Z"
                    stroke="currentColor"
                    strokeWidth="1.5"
                  />
                  <path d="M8 5V8.5M8 11H8.01" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                {error}
              </div>
            )}

            <div className="form-group">
              <label htmlFor="email">Email</label>
              <input
                type="email"
                id="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                required
                disabled={isLoading}
              />
            </div>

            <div className="form-group">
              <label htmlFor="password">Password</label>
              <input
                type="password"
                id="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                disabled={isLoading}
              />
            </div>

            <button type="submit" className="login-btn" disabled={isLoading}>
              {isLoading ? (
                <>
                  <svg className="spinner" width="20" height="20" viewBox="0 0 20 20">
                    <circle cx="10" cy="10" r="8" stroke="currentColor" strokeWidth="2" fill="none" strokeDasharray="50" />
                  </svg>
                  Signing in...
                </>
              ) : (
                'Sign In'
              )}
            </button>
          </form>

          <div className="login-footer">
            <p>
              Don't have an account? <a href="#signup">Create one</a>
            </p>
            <div className="login-features">
              <div className="feature-item">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                  <path d="M8 1L10.5 6H15.5L11.5 9.5L13 15L8 11.5L3 15L4.5 9.5L0.5 6H5.5L8 1Z" />
                </svg>
                Deploy in minutes
              </div>
              <div className="feature-item">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                  <circle cx="8" cy="8" r="7" />
                </svg>
                Your Azure account
              </div>
              <div className="feature-item">
                <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                  <rect x="2" y="2" width="12" height="12" rx="2" />
                </svg>
                Your data
              </div>
            </div>
          </div>
        </div>

        <div className="login-info">
          <h2>Enterprise RAG Made Simple</h2>
          <ul>
            <li>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M5 13L9 17L19 7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              <div>
                <strong>Your Azure Environment</strong>
                <p>Deploy to your own Azure subscription with full control</p>
              </div>
            </li>
            <li>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M5 13L9 17L19 7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              <div>
                <strong>Secure & Private</strong>
                <p>Zero Trust architecture with private endpoints and network isolation</p>
              </div>
            </li>
            <li>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M5 13L9 17L19 7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              <div>
                <strong>Your Documents</strong>
                <p>Upload and index your proprietary knowledge base</p>
              </div>
            </li>
            <li>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M5 13L9 17L19 7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              <div>
                <strong>Production Ready</strong>
                <p>Enterprise-grade RAG with monitoring, scaling, and compliance</p>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export default LoginPage;

