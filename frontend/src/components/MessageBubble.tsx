import { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import FeedbackButtons from './FeedbackButtons';
import { Message, AppConfig } from '../types';
import './MessageBubble.css';

interface MessageBubbleProps {
  message: Message;
  onFeedback: (
    messageId: string,
    feedbackType: 'thumbs_up' | 'thumbs_down',
    rating?: number,
    comment?: string
  ) => void;
  onShowSources: (message: Message) => void;
  config: AppConfig;
}

function MessageBubble({ message, onFeedback, onShowSources, config }: MessageBubbleProps) {
  const [showFeedbackForm, setShowFeedbackForm] = useState(false);

  const handleFeedbackClick = (feedbackType: 'thumbs_up' | 'thumbs_down') => {
    if (config.userFeedbackRating) {
      setShowFeedbackForm(true);
    } else {
      onFeedback(message.id, feedbackType);
    }
  };

  const handleFeedbackSubmit = (rating: number, comment: string, feedbackType: 'thumbs_up' | 'thumbs_down') => {
    onFeedback(message.id, feedbackType, rating, comment);
    setShowFeedbackForm(false);
  };

  return (
    <div className={`message-bubble ${message.role}`}>
      <div className="message-avatar">
        {message.role === 'user' ? (
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="16" cy="16" r="16" fill="var(--azure-gray-300)" />
            <path
              d="M16 16C18.21 16 20 14.21 20 12C20 9.79 18.21 8 16 8C13.79 8 12 9.79 12 12C12 14.21 13.79 16 16 16ZM16 18C13.33 18 8 19.34 8 22V24H24V22C24 19.34 18.67 18 16 18Z"
              fill="var(--azure-gray-600)"
            />
          </svg>
        ) : (
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="16" cy="16" r="16" fill="url(#avatarGradient)" />
            <path
              d="M16 8L20 12H18V16H20L16 20L12 16H14V12H12L16 8Z"
              fill="white"
              opacity="0.9"
            />
            <defs>
              <linearGradient id="avatarGradient" x1="0" y1="0" x2="32" y2="32">
                <stop stopColor="#0078d4" />
                <stop offset="1" stopColor="#5e5ce6" />
              </linearGradient>
            </defs>
          </svg>
        )}
      </div>

      <div className="message-content-wrapper">
        <div className="message-content">
          <ReactMarkdown remarkPlugins={[remarkGfm]}>{message.content}</ReactMarkdown>
        </div>

        {message.role === 'assistant' && (
          <div className="message-actions">
            {message.sources && message.sources.length > 0 && (
              <button className="sources-btn" onClick={() => onShowSources(message)}>
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path
                    d="M4 2H12C12.55 2 13 2.45 13 3V13C13 13.55 12.55 14 12 14H4C3.45 14 3 13.55 3 13V3C3 2.45 3.45 2 4 2Z"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    fill="none"
                  />
                  <path d="M5 5H11M5 8H11M5 11H9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
                {message.sources.length} {message.sources.length === 1 ? 'source' : 'sources'}
              </button>
            )}

            {config.enableUserFeedback && !message.feedback && (
              <FeedbackButtons
                onFeedback={handleFeedbackClick}
                showForm={showFeedbackForm}
                onSubmitForm={handleFeedbackSubmit}
                showRating={config.userFeedbackRating}
              />
            )}

            {message.feedback && (
              <div className="feedback-indicator">
                {message.feedback.type === 'thumbs_up' ? '👍' : '👎'} Feedback submitted
              </div>
            )}
          </div>
        )}

        <div className="message-timestamp">
          {message.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
        </div>
      </div>
    </div>
  );
}

export default MessageBubble;

