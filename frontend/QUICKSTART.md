# Quick Start Guide

Get the GPT-RAG frontend up and running in minutes!

## 🚀 Local Development (5 minutes)

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Configure Environment

Create a `.env` file:

```bash
cp env.example .env
```

Edit `.env` and set your orchestrator endpoint:

```env
VITE_ORCHESTRATOR_ENDPOINT=http://localhost:8000
```

### 3. Start Development Server

```bash
npm run dev
```

Open http://localhost:3000 in your browser. Done! 🎉

## 🐳 Docker Development (2 minutes)

### Run with Docker

```bash
docker-compose up
```

Open http://localhost:3000 in your browser.

## 📦 Production Build

### Build for Production

```bash
npm run build
```

The optimized files will be in the `dist/` directory.

### Preview Production Build

```bash
npm run preview
```

## 🔧 Common Tasks

### Run Linter

```bash
npm run lint
```

### Type Check

```bash
npx tsc --noEmit
```

### Build Docker Image

```bash
docker build -t gpt-rag-frontend .
```

### Run Docker Container

```bash
docker run -p 80:80 \
  -e ORCHESTRATOR_ENDPOINT=https://your-orchestrator.azurecontainerapps.io \
  gpt-rag-frontend
```

## 🎨 Customization

### Change Colors

Edit `src/index.css` and modify the CSS variables:

```css
:root {
  --azure-blue: #0078d4;      /* Primary color */
  --azure-purple: #5e5ce6;    /* Secondary color */
  --azure-light-blue: #50e6ff; /* Accent color */
}
```

### Modify API Endpoints

Edit `src/services/api.ts` to customize API calls.

### Update Components

All React components are in `src/components/`:
- `Header.tsx` - Top navigation bar
- `ChatContainer.tsx` - Main chat area
- `MessageBubble.tsx` - Individual messages
- `MessageInput.tsx` - Input field
- `Sidebar.tsx` - Sources panel
- `FeedbackButtons.tsx` - User feedback UI

## 🐛 Troubleshooting

### Port Already in Use

Change the port in `vite.config.ts`:

```typescript
export default defineConfig({
  server: {
    port: 3001, // Change this
  },
})
```

### Cannot Connect to Orchestrator

1. Check if orchestrator is running
2. Verify CORS settings on orchestrator
3. Check the endpoint URL in `.env`

### Build Errors

Clear cache and reinstall:

```bash
rm -rf node_modules dist
npm install
npm run build
```

## 📚 Next Steps

- Read the full [README.md](./README.md) for detailed documentation
- Check [DEPLOYMENT.md](./DEPLOYMENT.md) for Azure deployment
- Explore the [components](./src/components) to understand the code structure

## 💡 Tips

- Use `Ctrl+Shift+I` (or `Cmd+Option+I` on Mac) to open browser DevTools
- Check the Network tab to debug API calls
- Use React DevTools extension for debugging components
- The app uses TypeScript - hover over variables in VS Code for type info

## 🆘 Need Help?

- Check browser console for errors
- Review Docker/container logs: `docker logs <container-id>`
- Verify environment variables are set correctly
- Ensure orchestrator is accessible from your development machine

Happy coding! 🚀

