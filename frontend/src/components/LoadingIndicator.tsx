import './LoadingIndicator.css';

function LoadingIndicator() {
  return (
    <div className="loading-indicator">
      <div className="loading-avatar">
        <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="16" cy="16" r="16" fill="url(#loadingGradient)" />
          <path
            d="M16 8L20 12H18V16H20L16 20L12 16H14V12H12L16 8Z"
            fill="white"
            opacity="0.9"
          />
          <defs>
            <linearGradient id="loadingGradient" x1="0" y1="0" x2="32" y2="32">
              <stop stopColor="#0078d4" />
              <stop offset="1" stopColor="#5e5ce6" />
            </linearGradient>
          </defs>
        </svg>
      </div>
      <div className="loading-content">
        <div className="loading-dots">
          <span className="dot"></span>
          <span className="dot"></span>
          <span className="dot"></span>
        </div>
        <p className="loading-text">Thinking...</p>
      </div>
    </div>
  );
}

export default LoadingIndicator;

