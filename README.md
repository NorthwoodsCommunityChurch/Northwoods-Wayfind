# Northwoods Wayfind

Digital signage display for facility events, powered by the eSpace facility management platform.

## Features

- Real-time event display from eSpace API
- Auto-rotating featured event slides
- Sidebar with upcoming events list
- Welcome slides when no events are scheduled
- Responsive design optimized for TV displays
- Brand-compliant color scheme

## Setup

### Prerequisites

- Node.js (v18 or higher recommended)
- eSpace account with Digital Signage API access

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ESPACE_API_KEY` | Yes | - | Your eSpace API key |
| `ESPACE_DISPLAY_ID` | No | `7` | The display ID from eSpace |
| `PORT` | No | `8080` | Server port |

### Running Locally

```bash
# Set your API key
export ESPACE_API_KEY=your-api-key-here

# Optional: Set display ID if different from default
export ESPACE_DISPLAY_ID=7

# Start the server
node server.js

# Open in browser
open http://localhost:8080
```

## Architecture

- **index.html** - Single-page display application (HTML/CSS/JS)
- **server.js** - Node.js proxy server for eSpace API (handles CORS)

## API

The eSpace Digital Signage API endpoint is proxied through the local server at `/api/events` to handle CORS restrictions.

## Customization

### Colors

Brand colors are defined as CSS custom properties in `index.html`:

```css
:root {
    --blue-primary: #004C97;
    --blue-dark: #002855;
    --blue-light: #009CDE;
    --gold: #F1BE48;
    /* ... */
}
```

### Slide Timing

Adjust the `CONFIG` object in `index.html`:

```javascript
const CONFIG = {
    slideDuration: 10000,     // 10 seconds per slide
    refreshInterval: 300000,  // 5 minutes between API refreshes
    // ...
};
```

## License

Private - Northwoods Community Church
