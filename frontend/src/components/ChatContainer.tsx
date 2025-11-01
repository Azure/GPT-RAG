import { useRef, useEffect } from 'react';
import MessageBubble from './MessageBubble';
import MessageInput from './MessageInput';
import LoadingIndicator from './LoadingIndicator';
import { Message, AppConfig } from '../types';
import './ChatContainer.css';

interface ChatContainerProps {
  messages: Message[];
  isLoading: boolean;
  onSendMessage: (content: string) => void;
  onFeedback: (
    messageId: string,
    feedbackType: 'thumbs_up' | 'thumbs_down',
    rating?: number,
    comment?: string
  ) => void;
  onShowSources: (message: Message) => void;
  config: AppConfig;
}

function ChatContainer({
  messages,
  isLoading,
  onSendMessage,
  onFeedback,
  onShowSources,
  config,
}: ChatContainerProps) {
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isLoading]);

  return (
    <div className="chat-container">
      <div className="messages-area">
        {messages.length === 0 && !isLoading && (
          <div className="empty-state">
            <div className="empty-state-icon">
              <svg width="64" height="64" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="32" cy="32" r="32" fill="url(#emptyGradient)" opacity="0.1" />
                <path
                  d="M32 16C23.163 16 16 23.163 16 32C16 40.837 23.163 48 32 48C40.837 48 48 40.837 48 32C48 23.163 40.837 16 32 16ZM32 44C25.373 44 20 38.627 20 32C20 25.373 25.373 20 32 20C38.627 20 44 25.373 44 32C44 38.627 38.627 44 32 44Z"
                  fill="var(--azure-blue)"
                />
                <path
                  d="M26 28C26 29.105 25.105 30 24 30C22.895 30 22 29.105 22 28C22 26.895 22.895 26 24 26C25.105 26 26 26.895 26 28Z"
                  fill="var(--azure-blue)"
                />
                <path
                  d="M42 28C42 29.105 41.105 30 40 30C38.895 30 38 29.105 38 28C38 26.895 38.895 26 40 26C41.105 26 42 26.895 42 28Z"
                  fill="var(--azure-blue)"
                />
                <path
                  d="M38 36C38 39.314 35.314 42 32 42C28.686 42 26 39.314 26 36H28C28 38.209 29.791 40 32 40C34.209 40 36 38.209 36 36H38Z"
                  fill="var(--azure-blue)"
                />
                <defs>
                  <linearGradient id="emptyGradient" x1="0" y1="0" x2="64" y2="64">
                    <stop stopColor="#0078d4" />
                    <stop offset="1" stopColor="#5e5ce6" />
                  </linearGradient>
                </defs>
              </svg>
            </div>
            <h2 className="empty-state-title">Welcome to GPT-RAG Assistant</h2>
            <p className="empty-state-description">
              Ask me anything about your documents and data. I'll provide accurate answers based on your
              enterprise knowledge base.
            </p>
            <div className="empty-state-suggestions">
              <div className="suggestion-card" onClick={() => onSendMessage("What information do you have access to?")}>
                <span className="suggestion-icon">📚</span>
                <span>What information do you have access to?</span>
              </div>
              <div className="suggestion-card" onClick={() => onSendMessage("How can you help me?")}>
                <span className="suggestion-icon">💡</span>
                <span>How can you help me?</span>
              </div>
              <div className="suggestion-card" onClick={() => onSendMessage("Tell me about your capabilities")}>
                <span className="suggestion-icon">🎯</span>
                <span>Tell me about your capabilities</span>
              </div>
            </div>
          </div>
        )}

        {messages.map((message) => (
          <MessageBubble
            key={message.id}
            message={message}
            onFeedback={onFeedback}
            onShowSources={onShowSources}
            config={config}
          />
        ))}

        {isLoading && <LoadingIndicator />}
        <div ref={messagesEndRef} />
      </div>

      <div className="input-area">
        <MessageInput onSendMessage={onSendMessage} isLoading={isLoading} />
      </div>
    </div>
  );
}

export default ChatContainer;

