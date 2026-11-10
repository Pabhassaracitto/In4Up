const MAX_TEXT_LENGTH = 5000;
const MAX_READER_BYTES = 2_000_000;

function allowedOrigin(request, env) {
  const origin = request.headers.get('Origin') || '';
  const configured = (env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  // Missing origin configuration must not turn the proxy into a public CORS
  // relay. Add the Pages origin explicitly in the deployment environment.
  if (configured.length === 0) return '';
  return configured.includes(origin) ? origin : '';
}

function corsHeaders(request, env) {
  const origin = allowedOrigin(request, env);
  return {
    'access-control-allow-origin': origin || 'null',
    'access-control-allow-headers': 'content-type, authorization',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    vary: 'Origin',
  };
}

function jsonResponse(request, env, body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(request, env),
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

function allowedReaderHost(hostname, env) {
  const allowed = (env.READER_ALLOWED_HOSTS || '')
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);

  // An empty allowlist is intentionally fail-closed in production.
  if (allowed.length === 0) return false;
  const host = hostname.toLowerCase();
  return allowed.some((suffix) => host === suffix || host.endsWith(`.${suffix}`));
}

async function handleReader(request, env, url) {
  const target = url.searchParams.get('url');
  if (!target) return jsonResponse(request, env, { error: 'Missing url' }, 400);

  let targetUrl;
  try {
    targetUrl = new URL(target);
  } catch (_) {
    return jsonResponse(request, env, { error: 'Invalid url' }, 400);
  }

  if (!['http:', 'https:'].includes(targetUrl.protocol)) {
    return jsonResponse(request, env, { error: 'Only http/https is allowed' }, 400);
  }
  if (!allowedReaderHost(targetUrl.hostname, env)) {
    return jsonResponse(request, env, { error: 'Host is not allowlisted' }, 403);
  }

  // Do not follow redirects blindly: the final host must also be allowlisted.
  const upstream = await fetch(targetUrl.toString(), {
    redirect: 'manual',
    headers: {
      accept: 'text/html,application/xhtml+xml',
      'user-agent': 'In4Up-WebReader/1.0',
    },
  });
  if (upstream.status >= 300 && upstream.status < 400) {
    return jsonResponse(
      request,
      env,
      { error: 'Reader redirects are disabled; use the final allowlisted URL' },
      502,
    );
  }
  const length = Number(upstream.headers.get('content-length') || 0);
  if (length > MAX_READER_BYTES) {
    return jsonResponse(request, env, { error: 'Reader response is too large' }, 413);
  }

  const body = await upstream.text();
  if (new TextEncoder().encode(body).length > MAX_READER_BYTES) {
    return jsonResponse(request, env, { error: 'Reader response is too large' }, 413);
  }

  return new Response(body, {
    status: upstream.status,
    headers: {
      ...corsHeaders(request, env),
      'content-type': upstream.headers.get('content-type') || 'text/html; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

async function handleTranslate(request, env) {
  if (!env.TRANSLATION_URL) {
    return jsonResponse(request, env, { error: 'Translation upstream is not configured' }, 503);
  }

  const input = await request.json();
  const text = typeof input.text === 'string' ? input.text.trim() : '';
  if (!text || text.length > MAX_TEXT_LENGTH) {
    return jsonResponse(request, env, { error: 'Invalid text length' }, 400);
  }

  const upstreamHeaders = { 'content-type': 'application/json' };
  if (env.TRANSLATION_API_KEY) {
    upstreamHeaders.authorization = `Bearer ${env.TRANSLATION_API_KEY}`;
  }

  const upstream = await fetch(env.TRANSLATION_URL, {
    method: 'POST',
    headers: upstreamHeaders,
    body: JSON.stringify({
      text,
      sourceLang: input.sourceLang || 'auto',
      targetLang: input.targetLang || 'vi',
    }),
  });

  const responseText = await upstream.text();
  return new Response(responseText, {
    status: upstream.status,
    headers: {
      ...corsHeaders(request, env),
      'content-type': upstream.headers.get('content-type') || 'application/json',
      'cache-control': 'no-store',
    },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    }

    const url = new URL(request.url);
    try {
      if (url.pathname === '/health' && request.method === 'GET') {
        return jsonResponse(request, env, { ok: true, service: 'in4up-web-proxy' });
      }
      if (url.pathname === '/reader' && request.method === 'GET') {
        return await handleReader(request, env, url);
      }
      if (url.pathname === '/translate' && request.method === 'POST') {
        return await handleTranslate(request, env);
      }
      return jsonResponse(request, env, { error: 'Not found' }, 404);
    } catch (error) {
      return jsonResponse(request, env, { error: String(error) }, 502);
    }
  },
};
