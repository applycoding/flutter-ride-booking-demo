import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const port = Number(process.env.PORT ?? 43123);
const apiOrigin = process.env.API_ORIGIN ?? "http://127.0.0.1:8787";
const root = path.resolve(
  process.env.WEB_ROOT ?? path.join(path.dirname(new URL(import.meta.url).pathname), "../app/build/web"),
);
const api = new URL(apiOrigin);

const mime = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".ico", "image/x-icon"],
  [".wasm", "application/wasm"],
  [".ttf", "font/ttf"],
  [".otf", "font/otf"],
  [".txt", "text/plain; charset=utf-8"],
]);

if (!fs.existsSync(path.join(root, "index.html"))) {
  console.error(`Missing Flutter web build at ${root}. Run: flutter build web --dart-define=API_BASE=`);
  process.exit(1);
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url ?? "/", `http://127.0.0.1:${port}`);
  if (url.pathname === "/health" || url.pathname.startsWith("/v1/")) {
    proxyHttp(request, response, url);
    return;
  }
  serveFile(url.pathname, response);
});

server.on("upgrade", (request, socket, head) => {
  const proxy = http.request({
    hostname: api.hostname,
    port: api.port,
    path: request.url,
    method: request.method,
    headers: request.headers,
  });
  proxy.on("upgrade", (proxyResponse, proxySocket, proxyHead) => {
    const headers = [`HTTP/1.1 ${proxyResponse.statusCode} ${proxyResponse.statusMessage}`];
    for (const [key, value] of Object.entries(proxyResponse.headers)) {
      if (value === undefined) continue;
      const rendered = Array.isArray(value) ? value.join(", ") : value;
      headers.push(`${key}: ${rendered}`);
    }
    socket.write(`${headers.join("\r\n")}\r\n\r\n`);
    if (proxyHead.length > 0) socket.write(proxyHead);
    if (head.length > 0) proxySocket.write(head);
    proxySocket.pipe(socket);
    socket.pipe(proxySocket);
  });
  proxy.on("error", () => socket.destroy());
  proxy.end();
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Quay web preview on http://127.0.0.1:${port}`);
  console.log(`Proxying /v1 and /health to ${apiOrigin}`);
});

function proxyHttp(request, response, url) {
  const target = new URL(`${url.pathname}${url.search}`, api);
  const proxy = http.request(
    target,
    {
      method: request.method,
      headers: { ...request.headers, host: target.host },
    },
    (proxyResponse) => {
      response.writeHead(proxyResponse.statusCode ?? 502, proxyResponse.headers);
      proxyResponse.pipe(response);
    },
  );
  proxy.on("error", () => {
    response.writeHead(502, { "content-type": "application/json; charset=utf-8" });
    response.end(
      JSON.stringify({
        error: {
          code: "api_unreachable",
          message: "The ride API is not running. Start it with npm run dev in backend.",
        },
      }),
    );
  });
  request.pipe(proxy);
}

function serveFile(pathname, response) {
  const relative = pathname === "/" ? "index.html" : decodeURIComponent(pathname).replace(/^\/+/, "");
  let file = path.normalize(path.join(root, relative));
  if (!file.startsWith(root)) {
    response.writeHead(403).end();
    return;
  }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(root, "index.html");
  }
  response.writeHead(200, {
    "content-type": mime.get(path.extname(file)) ?? "application/octet-stream",
    "cache-control": "no-cache",
  });
  fs.createReadStream(file).pipe(response);
}
