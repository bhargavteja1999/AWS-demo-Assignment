const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 80;

app.get('/', (req, res) => {
  res.send(`<h1>Hello from Node.js App!</h1><p>Served by: ${os.hostname()}</p>`);
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK' });
});

app.listen(PORT, () => {
  console.log(`App running on http://0.0.0.0:${PORT}`);
});
