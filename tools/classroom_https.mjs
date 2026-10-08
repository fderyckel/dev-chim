// Local TLS edge for the synthetic classroom proof. No arbitrary upstream or route proxy.
import fs from "node:fs";
import https from "node:https";
import http from "node:http";
const [keyPath, certPath] = process.argv.slice(2);
const routes = new Set([
  "/api/v1/session", "/api/v1/session/logout", "/api/v1/classroom/classes",
  "/api/v1/classroom/preparation", "/api/v1/classroom/prepare-class",
  "/api/v1/classroom/add-student",
  "/api/v1/classroom/prepare-attendance", "/api/v1/classroom/submit-attendance",
  "/api/v1/classroom/correct-attendance",
  "/api/v1/calendar/preparation", "/api/v1/calendar/save-draft",
  "/api/v1/calendar/publish", "/api/v1/calendar/resolve",
  "/api/v1/classroom-demo/sign-in",
]);
const server = https.createServer({ key: fs.readFileSync(keyPath), cert: fs.readFileSync(certPath) }, (req, res) => {
  const path = new URL(req.url, "https://localhost:3013").pathname;
  if (req.headers.host !== "localhost:3013" || (path.startsWith("/api/") && !routes.has(path))) {
    res.writeHead(404, { "Cache-Control": "no-store" }); res.end(); return;
  }
  const upstream = http.request({ hostname: "127.0.0.1", port: routes.has(path) ? 4013 : 3014,
    method: req.method, path: req.url, headers: req.headers }, response => {
    res.writeHead(response.statusCode, { ...response.headers, "cache-control": "no-store" }); response.pipe(res);
  });
  upstream.on("error", () => { if (!res.headersSent) res.writeHead(503, { "Cache-Control": "no-store" }); res.end(); });
  req.pipe(upstream);
});
// Next development startup waits for its loopback hot-reload socket.
server.on("upgrade", (req, socket, head) => {
  if (req.headers.host !== "localhost:3013" || new URL(req.url, "https://localhost:3013").pathname !== "/_next/hmr") {
    socket.destroy(); return;
  }
  const upstream = http.request({ hostname: "127.0.0.1", port: 3014, path: req.url, headers: req.headers });
  upstream.on("upgrade", (response, peer, peerHead) => {
    socket.write(`HTTP/1.1 101 Switching Protocols\r\n${Object.entries(response.headers).map(([name, value]) => `${name}: ${value}`).join("\r\n")}\r\n\r\n`);
    if (peerHead.length) socket.write(peerHead);
    if (head.length) peer.write(head);
    socket.pipe(peer).pipe(socket);
    peer.on("error", () => socket.destroy());
    socket.on("error", () => peer.destroy());
  });
  upstream.on("error", () => socket.destroy());
  upstream.end();
});
server.listen(3013, "127.0.0.1", () => console.log("Classroom screen: https://localhost:3013/classroom"));
