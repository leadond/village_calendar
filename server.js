const http = require('http');
const fs = require('fs');
const path = require('path');

/**
 * Minimalist Zero-Dependency Static Server
 * Designed for Firebase App Hosting / Cloud Run
 */

const PORT = process.env.PORT || 8080;
const DIST_DIR = path.join(__dirname, 'dist');

const MIME_TYPES = {
    '.html': 'text/html',
    '.js': 'text/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.txt': 'text/plain',
    '.woff': 'application/font-woff',
    '.woff2': 'font/woff2',
    '.ttf': 'application/font-sfnt',
};

const server = http.createServer((req, res) => {
    // 1. Sanitize the URL path
    let urlPath = req.url.split('?')[0];
    let filePath = path.join(DIST_DIR, urlPath === '/' ? 'index.html' : urlPath);

    // 2. Identify MIME type
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} -> ${filePath}`);

    // 3. Serve the file
    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code === 'ENOENT') {
                // 4. SPA Fallback: If file not found, serve index.html for client-side routing
                fs.readFile(path.join(DIST_DIR, 'index.html'), (err, indexContent) => {
                    if (err) {
                        res.writeHead(404, { 'Content-Type': 'text/plain' });
                        res.end('404: Main index.html not found. Deployment mismatch.');
                    } else {
                        res.writeHead(200, { 'Content-Type': 'text/html' });
                        res.end(indexContent, 'utf-8');
                    }
                });
            } else {
                // Generic error
                res.writeHead(500);
                res.end(`Internal Server Error: ${error.code}`);
            }
        } else {
            // 5. Success
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`\x1b[32m🚀 Production server live on port ${PORT}\x1b[0m`);
    console.log(`\x1b[36mServing directory: ${DIST_DIR}\x1b[0m`);
});
