const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

function extractClientIp(req) {
  const xfwd = req.headers['x-forwarded-for'];
  if (xfwd) {
    const first = String(xfwd).split(',')[0].trim();
    if (first) return first.replace(/^::ffff:/, '');
  }
  const remote = (req.socket && req.socket.remoteAddress) || req.ip || 'Unknown';
  return String(remote).replace(/^::ffff:/, '');
}

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.get('/', (req, res) => {
  const ip = extractClientIp(req);
  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Your IP</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; }
    h1 { font-size: 1.5rem; }
    .ip { font-size: 2rem; font-weight: 600; }
  </style>
  </head>
<body>
  <h1>Your IP is:</h1>
  <div class="ip">${ip}</div>
  <p>Derived from X-Forwarded-For or remote address.</p>
</body>
</html>`;
  res.set('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(html);
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
