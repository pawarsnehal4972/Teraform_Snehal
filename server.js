// Express frontend: serves a small page and proxies /api/* calls to the Flask backend.
const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = (process.env.BACKEND_URL || "http://localhost:5000").replace(/\/$/, "");

const PAGE = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Express Frontend</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 640px; margin: 3rem auto; padding: 0 1rem; }
    button { padding: .6rem 1.2rem; font-size: 1rem; cursor: pointer; }
    pre { background: #f4f4f4; padding: 1rem; border-radius: 6px; overflow-x: auto; }
  </style>
</head>
<body>
  <h1>Express Frontend</h1>
  <p>Deployed on AWS with Terraform. This page talks to the Flask backend.</p>
  <button id="btn">Call Flask backend</button>
  <h3>Backend response</h3>
  <pre id="out">Click the button...</pre>
  <h3>Backend status (checked by Express)</h3>
  <pre id="status">Checking...</pre>
  <script>
    function show(id, p) {
      p.then(function (r) { return r.json(); })
       .then(function (d) { document.getElementById(id).textContent = JSON.stringify(d, null, 2); })
       .catch(function (e) { document.getElementById(id).textContent = "Error: " + e; });
    }
    document.getElementById("btn").onclick = function () { show("out", fetch("/api/message")); };
    show("status", fetch("/status"));
  </script>
</body>
</html>`;

app.get("/health", (req, res) => res.json({ status: "healthy", service: "express-frontend" }));

app.get("/status", async (req, res) => {
  try {
    const r = await fetch(BACKEND_URL + "/api/health", { signal: AbortSignal.timeout(3000) });
    res.json({ backend: BACKEND_URL, reachable: r.ok, response: await r.json() });
  } catch (err) {
    res.status(502).json({ backend: BACKEND_URL, reachable: false, error: String(err) });
  }
});

// Proxy any /api/* GET request to the Flask backend.
app.use("/api", async (req, res) => {
  try {
    const r = await fetch(BACKEND_URL + req.originalUrl, { signal: AbortSignal.timeout(5000) });
    res.status(r.status).type("application/json").send(await r.text());
  } catch (err) {
    res.status(502).json({ error: "Backend unreachable", detail: String(err) });
  }
});

app.get("/", (req, res) => res.type("html").send(PAGE));

app.listen(PORT, "0.0.0.0", () => console.log("Express frontend listening on " + PORT + ", backend=" + BACKEND_URL));
