import { Source } from '../types';
import './Sidebar.css';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
  sources: Source[];
}

function Sidebar({ isOpen, onClose, sources }: SidebarProps) {
  return (
    <>
      <div className={`sidebar-overlay ${isOpen ? 'visible' : ''}`} onClick={onClose} />
      <div className={`sidebar ${isOpen ? 'open' : ''}`}>
        <div className="sidebar-header">
          <h2 className="sidebar-title">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path
                d="M5 2.5H15C15.55 2.5 16 2.95 16 3.5V16.5C16 17.05 15.55 17.5 15 17.5H5C4.45 17.5 4 17.05 4 16.5V3.5C4 2.95 4.45 2.5 5 2.5Z"
                stroke="currentColor"
                strokeWidth="1.5"
                fill="none"
              />
              <path
                d="M6.5 6.5H13.5M6.5 10H13.5M6.5 13.5H11"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
              />
            </svg>
            Sources ({sources.length})
          </h2>
          <button className="sidebar-close-btn" onClick={onClose} title="Close sidebar">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path
                d="M5 5L15 15M5 15L15 5"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </svg>
          </button>
        </div>

        <div className="sidebar-content">
          {sources.length === 0 ? (
            <div className="sidebar-empty">
              <p>No sources available for this response.</p>
            </div>
          ) : (
            sources.map((source, index) => (
              <div key={index} className="source-card">
                <div className="source-header">
                  <div className="source-number">{index + 1}</div>
                  <div className="source-info">
                    <h3 className="source-title">{source.title || 'Untitled'}</h3>
                    {source.filepath && (
                      <div className="source-meta">
                        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path
                            d="M3.5 1.75H10.5L12.25 3.5V10.5C12.25 11.19 11.69 11.75 11 11.75H3.5C2.81 11.75 2.25 11.19 2.25 10.5V3C2.25 2.31 2.81 1.75 3.5 1.75Z"
                            stroke="currentColor"
                            strokeWidth="1"
                            fill="none"
                          />
                        </svg>
                        <span className="source-filepath">{source.filepath}</span>
                      </div>
                    )}
                    {source.page && (
                      <div className="source-meta">
                        <span className="source-page">Page {source.page}</span>
                      </div>
                    )}
                    {source.category && (
                      <div className="source-category">{source.category}</div>
                    )}
                  </div>
                </div>
                <div className="source-content">
                  <p>{source.content}</p>
                </div>
                {source.url && (
                  <a
                    href={source.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="source-link"
                  >
                    View source
                    <svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path
                        d="M10.5 7.58333V10.5C10.5 11.19 9.94 11.75 9.25 11.75H3.5C2.81 11.75 2.25 11.19 2.25 10.5V4.75C2.25 4.06 2.81 3.5 3.5 3.5H6.41667M8.75 2.25H12.25V5.75M6.41667 7.58333L12.25 1.75"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      />
                    </svg>
                  </a>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </>
  );
}

export default Sidebar;

