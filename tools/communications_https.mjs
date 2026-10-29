// Test-only same-origin TLS edge. Only named staff/session/classroom API routes reach the writer.
import fs from "node:fs";
import https from "node:https";
import http from "node:http";

const [keyPath, certPath] = process.argv.slice(2);
const origin = "https://localhost:3025";
const routes = new Set([
  "/api/v1/session",
  "/api/v1/session/logout",
  "/api/v1/communications/workspace",
  "/api/v1/communications/draft",
  "/api/v1/communications/review",
  "/api/v1/communications/status",
  "/api/v1/communications/metrics",
  "/api/v1/communications/receipt",
  "/api/v1/communications/create-draft",
  "/api/v1/communications/revise-draft",
  "/api/v1/communications/prepare-operation",
  "/api/v1/communications/submit-for-approval",
  "/api/v1/communications/approve-operation",
  "/api/v1/communications/open-notice",
  "/api/v1/communications/confirm-receipt",
  "/api/v1/communications/command-outcome",
  "/proof/persona/author",
  "/proof/persona/approver",
  "/proof/persona/recipient",
  "/proof/change-source",
]);

const server = https.createServer(
  { key: fs.readFileSync(keyPath), cert: fs.readFileSync(certPath) },
  (req, res) => {
    let path;
    try {
      path = new URL(req.url, origin).pathname;
    } catch {
      res.writeHead(400, { "Cache-Control": "no-store" });
      res.end();
      return;
    }
    if (
      req.headers.host !== "localhost:3025" ||
      ((path.startsWith("/api/") || path.startsWith("/proof/")) &&
        !routes.has(path))
    ) {
      res.writeHead(404, { "Cache-Control": "no-store" });
      res.end();
      return;
    }
    const upstream = http.request(
      {
        hostname: "127.0.0.1",
        port: routes.has(path) ? 4025 : 3026,
        method: req.method,
        path: req.url,
        headers: req.headers,
      },
      (response) => {
        res.writeHead(response.statusCode, {
          ...response.headers,
          "cache-control": "no-store",
        });
        response.pipe(res);
      },
    );
    upstream.on("error", () => {
      if (!res.headersSent) res.writeHead(503, { "Cache-Control": "no-store" });
      res.end();
    });
    req.on("aborted", () => upstream.destroy());
    req.pipe(upstream);
  },
);

server.on("upgrade", (req, socket, head) => {
  let path;
  try {
    path = new URL(req.url, origin).pathname;
  } catch {
    socket.destroy();
    return;
  }
  if (req.headers.host !== "localhost:3025" || path !== "/_next/hmr") {
    socket.destroy();
    return;
  }
  const upstream = http.request({
    hostname: "127.0.0.1",
    port: 3026,
    path: req.url,
    headers: req.headers,
  });
  upstream.on("upgrade", (response, peer, peerHead) => {
    socket.write(
      `HTTP/1.1 101 Switching Protocols\r\n${Object.entries(response.headers)
        .map(([name, value]) => `${name}: ${value}`)
        .join("\r\n")}\r\n\r\n`,
    );
    if (peerHead.length) socket.write(peerHead);
    if (head.length) peer.write(head);
    socket.pipe(peer).pipe(socket);
    peer.on("error", () => socket.destroy());
    socket.on("error", () => peer.destroy());
  });
  upstream.on("error", () => socket.destroy());
  upstream.end();
});

server.listen(3025, "127.0.0.1", () =>
  console.log("Fictional notices: https://localhost:3025/communications"),
);
