// Test-only same-origin TLS edge. Only named staff/session/classroom API routes reach the writer.
import fs from "node:fs";
import https from "node:https";
import http from "node:http";

const [keyPath, certPath] = process.argv.slice(2);
const origin = "https://localhost:3015";
const routes = new Set([
  "/api/v1/staff-login",
  "/api/v1/staff-login/cancel",
  "/api/v1/staff-login/replace-password",
  "/api/v1/staff-accounts",
  "/api/v1/staff-accounts/provision",
  "/api/v1/staff-accounts/revise-details",
  "/api/v1/staff-accounts/set-access",
  "/api/v1/staff-accounts/revoke-access-profile",
  "/api/v1/staff-accounts/suspend-access",
  "/api/v1/staff-accounts/reissue",
  "/api/v1/staff-preferences",
  "/api/v1/session",
  "/api/v1/session/logout",
  "/api/v1/classroom/classes",
  "/api/v1/classroom/preparation",
  "/api/v1/classroom/prepare-attendance",
  "/api/v1/classroom/submit-attendance",
  "/api/v1/classroom/correct-attendance",
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
    if (req.headers.host !== "localhost:3015" || (path.startsWith("/api/") && !routes.has(path))) {
      res.writeHead(404, { "Cache-Control": "no-store" });
      res.end();
      return;
    }
    const upstream = http.request(
      {
        hostname: "127.0.0.1",
        port: routes.has(path) ? 4015 : 3016,
        method: req.method,
        path: req.url,
        headers: req.headers,
      },
      (response) => {
        res.writeHead(response.statusCode, { ...response.headers, "cache-control": "no-store" });
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
  if (req.headers.host !== "localhost:3015" || path !== "/_next/hmr") {
    socket.destroy();
    return;
  }
  const upstream = http.request({ hostname: "127.0.0.1", port: 3016, path: req.url, headers: req.headers });
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

server.listen(3015, "127.0.0.1", () => console.log("Fictional staff sign-in: https://localhost:3015/sign-in"));
