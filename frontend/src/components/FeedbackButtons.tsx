import { useState } from 'react';
import './FeedbackButtons.css';

interface FeedbackButtonsProps {
  onFeedback: (feedbackType: 'thumbs_up' | 'thumbs_down') => void;
  showForm: boolean;
  onSubmitForm: (rating: number, comment: string, feedbackType: 'thumbs_up' | 'thumbs_down') => void;
  showRating: boolean;
}

function FeedbackButtons({ onFeedback, showForm, onSubmitForm, showRating }: FeedbackButtonsProps) {
  const [selectedFeedback, setSelectedFeedback] = useState<'thumbs_up' | 'thumbs_down' | null>(null);
  const [rating, setRating] = useState(0);
  const [comment, setComment] = useState('');

  const handleFeedbackClick = (type: 'thumbs_up' | 'thumbs_down') => {
    setSelectedFeedback(type);
    if (!showRating) {
      onFeedback(type);
    }
  };

  const handleSubmit = () => {
    if (selectedFeedback && rating > 0) {
      onSubmitForm(rating, comment, selectedFeedback);
      setRating(0);
      setComment('');
      setSelectedFeedback(null);
    }
  };

  const handleCancel = () => {
    setRating(0);
    setComment('');
    setSelectedFeedback(null);
  };

  return (
    <div className="feedback-buttons">
      {!showForm && (
        <div className="feedback-actions">
          <button
            className="feedback-btn thumbs-up"
            onClick={() => handleFeedbackClick('thumbs_up')}
            title="This was helpful"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path
                d="M4.5 14H2.5C1.67 14 1 13.33 1 12.5V7.5C1 6.67 1.67 6 2.5 6H4.5M9.5 5V3.5C9.5 2.12 8.38 1 7 1L4.5 6V14H12.28C12.93 14 13.49 13.53 13.62 12.89L14.87 6.39C15.03 5.57 14.42 4.8 13.59 4.8H9.5V5Z"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
          <button
            className="feedback-btn thumbs-down"
            onClick={() => handleFeedbackClick('thumbs_down')}
            title="This wasn't helpful"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path
                d="M4.5 2H2.5C1.67 2 1 2.67 1 3.5V8.5C1 9.33 1.67 10 2.5 10H4.5M9.5 11V12.5C9.5 13.88 8.38 15 7 15L4.5 10V2H12.28C12.93 2 13.49 2.47 13.62 3.11L14.87 9.61C15.03 10.43 14.42 11.2 13.59 11.2H9.5V11Z"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          </button>
        </div>
      )}

      {showForm && selectedFeedback && (
        <div className="feedback-form">
          <div className="feedback-form-header">
            <h4>Rate this response</h4>
          </div>

          <div className="rating-stars">
            {[1, 2, 3, 4, 5].map((star) => (
              <button
                key={star}
                className={`star-btn ${star <= rating ? 'active' : ''}`}
                onClick={() => setRating(star)}
              >
                ★
              </button>
            ))}
          </div>

          <textarea
            className="feedback-comment"
            placeholder="Additional comments (optional)"
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            rows={3}
          />

          <div className="feedback-form-actions">
            <button className="feedback-cancel-btn" onClick={handleCancel}>
              Cancel
            </button>
            <button
              className="feedback-submit-btn"
              onClick={handleSubmit}
              disabled={rating === 0}
            >
              Submit
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export default FeedbackButtons;

