<script module>
	// ---- config ----
	const RAW_API_BASE = (import.meta.env.VITE_API_URL ?? '').trim();
	function normalizeBase(raw) {
		if (!raw) return '';
		let b = raw.replace(/\/+$/, '');
		if (b.endsWith('/api')) b = b.slice(0, -4);
		return b;
	}
	const API_BASE = normalizeBase(RAW_API_BASE);
	const IS_MOCK = !API_BASE && RAW_API_BASE === '';
	const REQUEST_TIMEOUT_MS = Number(import.meta.env.VITE_REQUEST_TIMEOUT_MS ?? 1500);
	const ONLINE_MS = Number(import.meta.env.VITE_STATUS_ONLINE_THRESHOLD_MS ?? 1000);
	const DELAYED_MS = Number(import.meta.env.VITE_STATUS_DELAYED_THRESHOLD_MS ?? 5000);

	// ---- mock state (module-level so generator persists across mounts) ----
	const mockDevices = [
		{
			id: 'AA:BB:CC:00:00:01',
			type: 'anchor',
			name: 'Anchor-1',
			color: '#34D399',
			position: { x: 0, y: 0, z: 2.5 },
			lastSeen: Date.now()
		},
		{
			id: 'AA:BB:CC:00:00:02',
			type: 'anchor',
			name: 'Anchor-2',
			color: '#4F8EFF',
			position: { x: 5, y: 0, z: 2.5 },
			lastSeen: Date.now()
		},
		{
			id: 'AA:BB:CC:00:00:03',
			type: 'anchor',
			name: 'Anchor-3',
			color: '#FBBF24',
			position: { x: 5, y: 4, z: 2.5 },
			lastSeen: Date.now()
		},
		{
			id: 'AA:BB:CC:00:00:04',
			type: 'anchor',
			name: 'Anchor-4',
			color: '#F472B6',
			position: { x: 0, y: 4, z: 2.5 },
			lastSeen: Date.now()
		},
		{
			id: '11:22:33:00:00:01',
			type: 'tag',
			name: 'Tag-Alpha',
			color: '#A78BFA',
			position: { x: 2.5, y: 2, z: 0.8 },
			lastSeen: Date.now()
		},
		{
			id: '11:22:33:00:00:02',
			type: 'tag',
			name: 'Tag-Beta',
			color: '#22D3EE',
			position: { x: 1.2, y: 1.5, z: 0.5 },
			lastSeen: Date.now()
		}
	];

	const mockHistory = new Map();
	const mockStartTs = Date.now();
	let mockTickHandle = null;
	let mockTickRefcount = 0;

	function statusFromLastSeen(lastSeen) {
		const age = Date.now() - lastSeen;
		if (age < ONLINE_MS) return 'online';
		if (age < DELAYED_MS) return 'delayed';
		return 'offline';
	}

	function annotateDevice(d) {
		return { ...d, status: statusFromLastSeen(d.lastSeen) };
	}

	function clone(obj) {
		return JSON.parse(JSON.stringify(obj));
	}

	function mockTick() {
		const t = (Date.now() - mockStartTs) / 1000;
		for (const d of mockDevices) {
			d.lastSeen = Date.now();
			if (d.type !== 'tag') continue;
			const seed = parseInt(d.id.replace(/[^0-9a-f]/gi, '').slice(-4), 16);
			const phase = (seed % 100) / 50;
			const speed = 0.4 + (seed % 7) / 20;
			const cx = 2.5;
			const cy = 2;
			const r = 1.5;
			d.position = {
				x: cx + Math.cos(t * speed + phase) * r,
				y: cy + Math.sin(t * speed + phase) * r,
				z: 0.5 + Math.sin(t * speed * 0.5 + phase) * 0.3
			};
			const residual = 0.05 + Math.abs(Math.sin(t + phase)) * 0.4;
			const entry = {
				timestamp: Date.now(),
				position: { ...d.position },
				residual
			};
			if (!mockHistory.has(d.id)) mockHistory.set(d.id, []);
			const arr = mockHistory.get(d.id);
			arr.push(entry);
			const cutoff = Date.now() - 60 * 60 * 1000;
			while (arr.length && arr[0].timestamp < cutoff) arr.shift();
		}
	}

	function startMockTicker() {
		mockTickRefcount++;
		if (mockTickHandle) return;
		mockTickHandle = setInterval(mockTick, 100);
	}

	function stopMockTicker() {
		mockTickRefcount = Math.max(0, mockTickRefcount - 1);
		if (mockTickRefcount === 0 && mockTickHandle) {
			clearInterval(mockTickHandle);
			mockTickHandle = null;
		}
	}

	// ---- transport ----
	async function realRequest(path, init) {
		const ac = new AbortController();
		const timer = setTimeout(() => ac.abort(), REQUEST_TIMEOUT_MS);
		try {
			const res = await fetch(`${API_BASE}${path}`, {
				...init,
				signal: ac.signal,
				headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) }
			});
			if (!res.ok) throw new Error(`API ${res.status}: ${await res.text()}`);
			const text = await res.text();
			return text ? JSON.parse(text) : null;
		} finally {
			clearTimeout(timer);
		}
	}

	function mockRequest(path, init) {
		const method = (init?.method ?? 'GET').toUpperCase();
		const body = init?.body ? JSON.parse(init.body) : null;

		if (path === '/api/health') return Promise.resolve({ status: 'ok' });
		if (path === '/api') {
			return Promise.resolve({
				endpoints: [
					'GET /api/health',
					'GET /api/devices',
					'GET /api/anchors',
					'GET /api/tags',
					'GET /api/positions'
				]
			});
		}

		if (path === '/api/devices' && method === 'GET') {
			return Promise.resolve({ devices: mockDevices.map(annotateDevice).map(clone) });
		}
		if (path === '/api/anchors' && method === 'GET') {
			return Promise.resolve({
				anchors: mockDevices
					.filter((d) => d.type === 'anchor')
					.map(annotateDevice)
					.map(clone)
			});
		}
		if (path === '/api/tags' && method === 'GET') {
			return Promise.resolve({
				tags: mockDevices
					.filter((d) => d.type === 'tag')
					.map(annotateDevice)
					.map(clone)
			});
		}
		if (path === '/api/positions' && method === 'GET') {
			return Promise.resolve({
				positions: mockDevices
					.filter((d) => d.type === 'tag')
					.map((d) => ({
						tagId: d.id,
						position: { ...d.position },
						timestamp: d.lastSeen,
						residual: 0.05 + Math.random() * 0.3
					}))
			});
		}

		const matchDevice = path.match(/^\/api\/devices\/([^/]+)$/);
		if (matchDevice) {
			const id = decodeURIComponent(matchDevice[1]);
			const idx = mockDevices.findIndex((d) => d.id === id);
			if (idx < 0) return Promise.reject(new Error(`API 404: ${id}`));
			if (method === 'GET') return Promise.resolve(annotateDevice(clone(mockDevices[idx])));
			if (method === 'PUT') {
				if (body?.name !== undefined) mockDevices[idx].name = body.name;
				if (body?.color !== undefined) mockDevices[idx].color = body.color;
				return Promise.resolve(annotateDevice(clone(mockDevices[idx])));
			}
			if (method === 'DELETE') {
				mockDevices.splice(idx, 1);
				mockHistory.delete(id);
				return Promise.resolve({ ok: true });
			}
		}

		const matchAnchorPos = path.match(/^\/api\/anchors\/([^/]+)\/position$/);
		if (matchAnchorPos && method === 'PUT') {
			const id = decodeURIComponent(matchAnchorPos[1]);
			const dev = mockDevices.find((d) => d.id === id && d.type === 'anchor');
			if (!dev) return Promise.reject(new Error(`API 404: ${id}`));
			dev.position = { x: Number(body.x), y: Number(body.y), z: Number(body.z) };
			return Promise.resolve(annotateDevice(clone(dev)));
		}

		const matchPosOne = path.match(/^\/api\/positions\/([^/]+)$/);
		if (matchPosOne && method === 'GET') {
			const id = decodeURIComponent(matchPosOne[1]);
			const dev = mockDevices.find((d) => d.id === id && d.type === 'tag');
			if (!dev) return Promise.reject(new Error(`API 404: ${id}`));
			return Promise.resolve({
				tagId: dev.id,
				position: { ...dev.position },
				timestamp: dev.lastSeen,
				residual: 0.05 + Math.random() * 0.3
			});
		}

		const matchHistory = path.match(/^\/api\/positions\/([^/?]+)\/history\?from=(\d+)&to=(\d+)$/);
		if (matchHistory && method === 'GET') {
			const id = decodeURIComponent(matchHistory[1]);
			const from = Number(matchHistory[2]);
			const to = Number(matchHistory[3]);
			const all = mockHistory.get(id) ?? [];
			return Promise.resolve({
				history: all.filter((e) => e.timestamp >= from && e.timestamp <= to).map(clone)
			});
		}

		if (path === '/api/system/info' && method === 'GET') {
			return Promise.resolve({
				uptime: Math.floor((Date.now() - mockStartTs) / 1000),
				wifi: { ssid: 'UWBP', password: 'abcd1234', ip: '10.42.0.1' },
				version: 'mock-0.1'
			});
		}

		if (path === '/api/shutdown' && method === 'POST') {
			return Promise.resolve({ ok: true });
		}

		return Promise.reject(new Error(`Mock: kein Handler für ${method} ${path}`));
	}

	function request(path, init) {
		return IS_MOCK ? mockRequest(path, init) : realRequest(path, init);
	}

	// ---- endpoint groups ----
	const devicesApi = {
		list: () => request('/api/devices'),
		get: (id) => request(`/api/devices/${encodeURIComponent(id)}`),
		update: (id, data) =>
			request(`/api/devices/${encodeURIComponent(id)}`, {
				method: 'PUT',
				body: JSON.stringify(data)
			}),
		remove: (id) => request(`/api/devices/${encodeURIComponent(id)}`, { method: 'DELETE' })
	};

	const anchorsApi = {
		list: () => request('/api/anchors'),
		setPosition: (id, x, y, z) =>
			request(`/api/anchors/${encodeURIComponent(id)}/position`, {
				method: 'PUT',
				body: JSON.stringify({ x, y, z })
			})
	};

	const positionsApi = {
		all: () => request('/api/positions'),
		one: (id) => request(`/api/positions/${encodeURIComponent(id)}`),
		history: (id, from, to) =>
			request(`/api/positions/${encodeURIComponent(id)}/history?from=${from}&to=${to}`)
	};

	const systemApi = {
		health: () => request('/api/health'),
		routes: () => request('/api'),
		info: () => request('/api/system/info'),
		shutdown: () => request('/api/shutdown', { method: 'POST' })
	};

	export { IS_MOCK, startMockTicker, stopMockTicker };
</script>

<script>
	import { setContext, onDestroy } from 'svelte';

	// ---- props ----
	let { children } = $props();

	// ---- mock lifecycle ----
	if (IS_MOCK) {
		startMockTicker();
		onDestroy(() => stopMockTicker());
	}

	// ---- context ----
	setContext('api', {
		isMock: IS_MOCK,
		request,
		devices: devicesApi,
		anchors: anchorsApi,
		positions: positionsApi,
		system: systemApi
	});
</script>

{@render children()}
