const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Configuration - use environment variables
const PORT = process.env.PORT || 8080;
const ESPACE_API_KEY = process.env.ESPACE_API_KEY;
const ESPACE_DISPLAY_ID = process.env.ESPACE_DISPLAY_ID || '7';

if (!ESPACE_API_KEY) {
    console.error('ERROR: ESPACE_API_KEY environment variable is required');
    console.error('Set it with: export ESPACE_API_KEY=your-api-key');
    process.exit(1);
}

const API_URL = `https://app.espace.cool/FacilieSpace/DigitalSignage/GetDisplayEvents/${ESPACE_DISPLAY_ID}?key=${ESPACE_API_KEY}`;

// MIME types for static files
const mimeTypes = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon'
};

const server = http.createServer((req, res) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);

    // API proxy endpoint
    if (req.url === '/api/events') {
        https.get(API_URL, (apiRes) => {
            let data = '';
            apiRes.on('data', chunk => data += chunk);
            apiRes.on('end', () => {
                res.writeHead(200, {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                });
                res.end(data);
            });
        }).on('error', (err) => {
            console.error('API fetch error:', err);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Failed to fetch events' }));
        });
        return;
    }

    // Serve static files
    let filePath = req.url === '/' ? '/index.html' : req.url;
    filePath = path.join(__dirname, filePath);

    const ext = path.extname(filePath);
    const contentType = mimeTypes[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, content) => {
        if (err) {
            if (err.code === 'ENOENT') {
                res.writeHead(404);
                res.end('File not found');
            } else {
                res.writeHead(500);
                res.end('Server error');
            }
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        }
    });
});

server.listen(PORT, () => {
    console.log(`
╔════════════════════════════════════════════════════════╗
║         Northwoods Wayfind Server Running              ║
╠════════════════════════════════════════════════════════╣
║  Open in browser:  http://localhost:${PORT}               ║
║  Press Ctrl+C to stop                                  ║
╚════════════════════════════════════════════════════════╝
`);
});
