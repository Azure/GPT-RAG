# Contributing to GPT-RAG Frontend

Thank you for your interest in contributing to the GPT-RAG frontend! This guide will help you get started.

## Development Setup

### Prerequisites

- Node.js 18+ and npm
- Git
- VS Code (recommended) with recommended extensions
- Basic knowledge of React, TypeScript, and CSS

### Getting Started

1. **Fork and Clone**

```bash
git clone https://github.com/your-username/GPT-RAG.git
cd GPT-RAG/frontend
```

2. **Install Dependencies**

```bash
npm install
```

3. **Start Development Server**

```bash
npm run dev
```

## Code Style

### TypeScript

- Use TypeScript for all new files
- Define proper types and interfaces in `src/types.ts`
- Avoid using `any` type
- Enable strict mode checks

### React

- Use functional components with hooks
- Keep components small and focused
- Extract reusable logic into custom hooks
- Use meaningful component and prop names

### CSS

- Use CSS modules or component-scoped CSS files
- Follow BEM naming convention for class names
- Use CSS variables for colors and common values
- Ensure responsive design (mobile-first approach)

### File Structure

```
src/
├── components/       # React components (one per file)
│   ├── ComponentName.tsx
│   └── ComponentName.css
├── services/        # API and external services
├── hooks/           # Custom React hooks (if needed)
├── types.ts         # TypeScript type definitions
└── utils/           # Utility functions
```

## Coding Guidelines

### Components

```typescript
// Good: Functional component with proper types
interface MyComponentProps {
  title: string;
  onAction: () => void;
}

function MyComponent({ title, onAction }: MyComponentProps) {
  return (
    <div className="my-component">
      <h2>{title}</h2>
      <button onClick={onAction}>Action</button>
    </div>
  );
}

export default MyComponent;
```

### API Calls

- All API calls should go through `src/services/api.ts`
- Handle errors gracefully with try-catch
- Show user-friendly error messages
- Use proper TypeScript types for requests/responses

### State Management

- Use React hooks (`useState`, `useEffect`, etc.)
- Keep state as local as possible
- Lift state up only when necessary
- Consider useContext for deeply nested props

## Testing

### Manual Testing

Before submitting:
1. Test on different screen sizes (mobile, tablet, desktop)
2. Test with different browsers (Chrome, Firefox, Safari, Edge)
3. Test all user interactions
4. Verify error handling

### Checklist

- [ ] Code follows style guidelines
- [ ] No console errors or warnings
- [ ] Responsive design works on mobile
- [ ] All TypeScript types are properly defined
- [ ] Component is accessible (keyboard navigation, screen readers)
- [ ] Changes are documented if needed

## Making Changes

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation changes
- `refactor/description` - Code refactoring

### Commit Messages

Use clear, descriptive commit messages:

```
Good:
- "Add user feedback rating component"
- "Fix sidebar not closing on mobile"
- "Update API service to handle timeouts"

Avoid:
- "Update"
- "Fix bug"
- "Changes"
```

### Pull Request Process

1. **Create a Branch**
```bash
git checkout -b feature/my-new-feature
```

2. **Make Your Changes**
- Write clean, documented code
- Follow the style guide
- Test your changes

3. **Commit Your Changes**
```bash
git add .
git commit -m "Add feature description"
```

4. **Push to Your Fork**
```bash
git push origin feature/my-new-feature
```

5. **Open a Pull Request**
- Describe what you changed and why
- Reference any related issues
- Include screenshots for UI changes
- Ensure all checks pass

## Common Tasks

### Adding a New Component

1. Create component file: `src/components/MyComponent.tsx`
2. Create CSS file: `src/components/MyComponent.css`
3. Define props interface
4. Implement component
5. Export component
6. Import and use in parent component

### Adding a New API Endpoint

1. Define request/response types in `src/types.ts`
2. Add method to `src/services/api.ts`
3. Handle errors appropriately
4. Use the new method in your component

### Styling Guidelines

**Colors:**
Use CSS variables from `src/index.css`:
```css
.my-component {
  background-color: var(--azure-blue);
  color: var(--azure-gray-900);
  border: 1px solid var(--azure-gray-300);
}
```

**Spacing:**
Use consistent spacing (multiples of 4px or 8px)

**Typography:**
Follow existing font sizes and weights

**Animations:**
Keep animations subtle and fast (200-300ms)

## Accessibility

### Requirements

- All interactive elements must be keyboard accessible
- Proper ARIA labels for screen readers
- Sufficient color contrast (WCAG AA minimum)
- Focus indicators visible and clear
- Semantic HTML elements

### Example

```tsx
<button
  className="action-btn"
  onClick={handleClick}
  aria-label="Submit feedback"
  disabled={isLoading}
>
  Submit
</button>
```

## Performance

### Best Practices

- Lazy load heavy components if needed
- Optimize images (use appropriate formats and sizes)
- Minimize bundle size
- Use React.memo for expensive components
- Avoid unnecessary re-renders

## Documentation

### Code Comments

- Comment complex logic
- Explain "why" not "what"
- Use JSDoc for utility functions

```typescript
/**
 * Formats a date string for display in the chat interface
 * @param date - The date to format
 * @returns Formatted time string (HH:MM AM/PM)
 */
function formatTimestamp(date: Date): string {
  return date.toLocaleTimeString([], { 
    hour: '2-digit', 
    minute: '2-digit' 
  });
}
```

### Component Documentation

Include prop descriptions in the interface:

```typescript
interface MessageBubbleProps {
  /** The message object containing content and metadata */
  message: Message;
  /** Callback when user provides feedback */
  onFeedback: (id: string, type: 'thumbs_up' | 'thumbs_down') => void;
  /** Whether to show the feedback buttons */
  showFeedback?: boolean;
}
```

## Questions or Issues?

- Check existing issues before creating new ones
- Be respectful and constructive
- Provide as much context as possible
- Include error messages, screenshots, or logs

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

Thank you for contributing! 🎉

