import http from 'node:http';
import crypto from 'node:crypto';

const HOST = process.env.RISU_CODEX_HOST || '127.0.0.1';
const PORT = Number(process.env.RISU_CODEX_PORT || 6969);
const PASSWORD = String(process.env.RISU_CODEX_API_PASSWORD || '');
const UPSTREAM = String(process.env.RISU_CODEX_UPSTREAM || 'http://127.0.0.1:8082').replace(/\/+$/, '');
const PUBLIC_BASE_URL = String(process.env.RISU_CODEX_PUBLIC_BASE_URL || `http://${HOST}:${PORT}`);

function timingSafeEqual(a, b) {
  const left = Buffer.from(String(a || ''));
  const right = Buffer.from(String(b || ''));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function getRequestPassword(request) {
  const header = String(request.headers.authorization || '');
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (match) return match[1];
  return (
    request.headers['x-api-key'] ||
    request.headers['anthropic-api-key'] ||
    request.headers['api-key'] ||
    ''
  );
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(payload));
}

function isAuthorized(request) {
  if (!PASSWORD) return false;
  return timingSafeEqual(getRequestPassword(request), PASSWORD);
}

function copyHeaders(headers) {
  const next = {};
  for (const [key, value] of Object.entries(headers)) {
    const lower = key.toLowerCase();
    if (['host', 'connection', 'content-length'].includes(lower)) continue;
    next[key] = value;
  }
  return next;
}

async function readBody(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  return Buffer.concat(chunks);
}

async function proxyRequest(request, response, url) {
  const body = ['GET', 'HEAD'].includes(request.method) ? undefined : await readBody(request);
  const upstreamUrl = `${UPSTREAM}${url.pathname}${url.search}`;
  const upstreamResponse = await fetch(upstreamUrl, {
    method: request.method,
    headers: copyHeaders(request.headers),
    body,
    duplex: body ? 'half' : undefined,
  });

  const responseHeaders = {};
  upstreamResponse.headers.forEach((value, key) => {
    if (!['content-encoding', 'transfer-encoding', 'connection'].includes(key.toLowerCase())) {
      responseHeaders[key] = value;
    }
  });

  response.writeHead(upstreamResponse.status, responseHeaders);
  if (!upstreamResponse.body) {
    response.end();
    return;
  }

  const reader = upstreamResponse.body.getReader();
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    response.write(Buffer.from(value));
  }
  response.end();
}

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url || '/', `http://${request.headers.host || `${HOST}:${PORT}`}`);

  try {
    if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/health')) {
      return sendJson(response, 200, {
        ok: true,
        service: 'Risu Codex password proxy',
        publicBaseUrl: PUBLIC_BASE_URL,
        upstream: UPSTREAM,
        authRequired: true,
        endpoints: ['/v1/messages', '/v1/models'],
      });
    }

    if (!isAuthorized(request)) {
      return sendJson(response, 401, {
        error: {
          message: 'Unauthorized. Put the generated password into RisuAI API password.',
          type: 'authentication_error',
        },
      });
    }

    await proxyRequest(request, response, url);
  } catch (error) {
    console.error('[Risu Codex Proxy] Request failed:', error);
    sendJson(response, 500, {
      error: {
        message: error.message || String(error),
        type: 'server_error',
      },
    });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[Risu Codex Proxy] Listening on http://${HOST}:${PORT}`);
  console.log(`[Risu Codex Proxy] Upstream: ${UPSTREAM}`);
  console.log(`[Risu Codex Proxy] Public base URL: ${PUBLIC_BASE_URL}`);
});
