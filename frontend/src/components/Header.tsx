import './Header.css';

interface HeaderProps {
  onNewChat: () => void;
  onBack?: () => void;
}

function Header({ onNewChat, onBack }: HeaderProps) {
  return (
    <header className="header">
      <div className="header-content">
        <div className="header-left">
          {onBack && (
            <button className="back-btn" onClick={onBack} title="Back to dashboard">
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path
                  d="M12 4L6 10L12 16"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </button>
          )}
          <div className="logo">
            <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
              <rect width="32" height="32" rx="6" fill="url(#gradient)" />
              <path
                d="M16 8L20 12H18V16H20L16 20L12 16H14V12H12L16 8Z"
                fill="white"
                opacity="0.9"
              />
              <defs>
                <linearGradient id="gradient" x1="0" y1="0" x2="32" y2="32">
                  <stop stopColor="#0078d4" />
                  <stop offset="1" stopColor="#5e5ce6" />
                </linearGradient>
              </defs>
            </svg>
            <h1 className="header-title">GPT-RAG Assistant</h1>
          </div>
        </div>
        <div className="header-right">
          <button className="new-chat-btn" onClick={onNewChat} title="Start new conversation">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path
                d="M10 4V16M4 10H16"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
            New Chat
          </button>
        </div>
      </div>
    </header>
  );
}

export default Header;
