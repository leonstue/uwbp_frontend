const BACKEND = (process.env.BACKEND_URL ?? 'http://uwbp.:8080').replace(/\/+$/, '');
const PROXY_TIMEOUT_MS = Number(process.env.PROXY_TIMEOUT_MS ?? 2000);

export async function handle({ event, resolve }) {
	const { pathname, search } = event.url;
	if (!pathname.startsWith('/api')) {
		return resolve(event);
	}

	const target = `${BACKEND}${pathname}${search}`;
	const ac = new AbortController();
	const timer = setTimeout(() => ac.abort(), PROXY_TIMEOUT_MS);

	const headers = new Headers(event.request.headers);
	headers.delete('host');
	headers.delete('connection');

	try {
		const init = {
			method: event.request.method,
			headers,
			signal: ac.signal,
			redirect: 'manual'
		};
		if (!['GET', 'HEAD'].includes(event.request.method)) {
			init.body = await event.request.arrayBuffer();
		}
		const upstream = await fetch(target, init);
		const respHeaders = new Headers(upstream.headers);
		respHeaders.delete('content-encoding');
		respHeaders.delete('content-length');
		return new Response(upstream.body, {
			status: upstream.status,
			statusText: upstream.statusText,
			headers: respHeaders
		});
	} catch (e) {
		const reason = e?.name === 'AbortError' ? 'upstream timeout' : String(e?.message ?? e);
		return new Response(JSON.stringify({ error: reason }), {
			status: 502,
			headers: { 'content-type': 'application/json' }
		});
	} finally {
		clearTimeout(timer);
	}
}
