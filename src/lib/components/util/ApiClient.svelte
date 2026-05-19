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

	// ---- mock table geometry ----
	const TABLE = { x: 1.6, y: 0.8, z: 0.75 };
	const TAG_1_ID = '11:22:33:00:00:01';
	const TAG_2_ID = '11:22:33:00:00:02';
	const DEFAULT_TAG_1 = { x: 0.4, y: 0.4, z: 0.78 };
	const DEFAULT_TAG_2 = { x: 1.2, y: 0.4, z: 0.78 };

	// ---- mock state (module-level so generator persists across mounts) ----
	const mockDevices = [
		{
			id: 'AA:BB:CC:00:00:01',
			type: 'anchor',
			name: 'Anchor-1',
			color: '#34D399',
			position: { x: 0, y: 0, z: TABLE.z },
			lastSeen: Date.now()
		},
		{
			id: 'AA:BB:CC:00:00:02',
			type: 'anchor',
			name: 'Anchor-2',
			color: '#4F8EFF',
			position: { x: TABLE.x, y: 0, z: TABLE.z },
			lastSeen: Date.now()
		},
		{
			id: 'AA:BB:CC:00:00:03',
			type: 'anchor',
			name: 'Anchor-3',
			color: '#FBBF24',
			position: { x: TABLE.x, y: TABLE.y, z: TABLE.z },
			lastSeen: Date.now()
		},
		{
			id: 'AA:BB:CC:00:00:04',
			type: 'anchor',
			name: 'Anchor-4',
			color: '#F472B6',
			position: { x: 0, y: TABLE.y, z: TABLE.z },
			lastSeen: Date.now()
		},
		{
			id: TAG_1_ID,
			type: 'tag',
			name: 'Tag-Alpha',
			color: '#A78BFA',
			position: { ...DEFAULT_TAG_1 },
			lastSeen: Date.now()
		},
		{
			id: TAG_2_ID,
			type: 'tag',
			name: 'Tag-Beta',
			color: '#22D3EE',
			position: { ...DEFAULT_TAG_2 },
			lastSeen: Date.now()
		}
	];

	const mockHistory = new Map();
	const mockStartTs = Date.now();
	let mockTickHandle = null;
	let mockTickRefcount = 0;

	// ---- demo replay state ----
	let demoRecording = null;
	let replayActive = false;
	let replayStartTs = 0;
	let replayLoop = false;

	function loadRecording() {
		if (typeof localStorage === 'undefined') return null;
		try {
			const raw = localStorage.getItem('uwbp.demoRecording');
			if (!raw) return null;
			const parsed = JSON.parse(raw);
			if (!parsed?.tracks) return null;
			return parsed;
		} catch {
			return null;
		}
	}

	function tagPositionAt(trackId, elapsedMs) {
		const rec = demoRecording;
		if (!rec) return null;
		const track = rec.tracks?.[trackId];
		if (!track || track.length === 0) {
			return rec.startPositions?.[trackId] ?? null;
		}
		const duration = track[track.length - 1].t;
		let t = elapsedMs;
		if (replayLoop && duration > 0) {
			t = elapsedMs % duration;
		} else if (t >= duration) {
			return { x: track[track.length - 1].x, y: track[track.length - 1].y, z: track[track.length - 1].z };
		}
		if (t <= track[0].t) return { x: track[0].x, y: track[0].y, z: track[0].z };
		let lo = 0;
		let hi = track.length - 1;
		while (lo + 1 < hi) {
			const mid = (lo + hi) >> 1;
			if (track[mid].t <= t) lo = mid;
			else hi = mid;
		}
		const a = track[lo];
		const b = track[hi];
		const span = Math.max(1, b.t - a.t);
		const k = (t - a.t) / span;
		return {
			x: a.x + (b.x - a.x) * k,
			y: a.y + (b.y - a.y) * k,
			z: a.z + (b.z - a.z) * k
		};
	}

	function startDemoReplay({ loop = false } = {}) {
		demoRecording = loadRecording();
		if (!demoRecording) return false;
		replayLoop = loop;
		replayActive = true;
		replayStartTs = Date.now();
		applyStartPositions();
		return true;
	}

	function stopDemoReplay() {
		replayActive = false;
	}

	function applyStartPositions() {
		const sp = demoRecording?.startPositions ?? {};
		const t1 = mockDevices.find((d) => d.id === TAG_1_ID);
		const t2 = mockDevices.find((d) => d.id === TAG_2_ID);
		if (t1) t1.position = { ...(sp[TAG_1_ID] ?? DEFAULT_TAG_1) };
		if (t2) t2.position = { ...(sp[TAG_2_ID] ?? DEFAULT_TAG_2) };
	}

	function refreshFromStorage() {
		demoRecording = loadRecording();
		applyStartPositions();
	}

	function installDemoListeners() {
		if (typeof window === 'undefined') return () => {};
		const onStart = (e) => startDemoReplay({ loop: e?.detail?.loop ?? false });
		const onStop = () => stopDemoReplay();
		const onReset = () => {
			stopDemoReplay();
			refreshFromStorage();
		};
		const onReload = () => refreshFromStorage();
		const onKey = (ev) => {
			if (!ev.ctrlKey || !ev.shiftKey) return;
			if (ev.code === 'KeyP') {
				ev.preventDefault();
				startDemoReplay({ loop: false });
			} else if (ev.code === 'KeyL') {
				ev.preventDefault();
				startDemoReplay({ loop: true });
			} else if (ev.code === 'KeyR') {
				ev.preventDefault();
				stopDemoReplay();
				refreshFromStorage();
			}
		};
		window.addEventListener('uwbp:start-demo', onStart);
		window.addEventListener('uwbp:stop-demo', onStop);
		window.addEventListener('uwbp:reset-tags', onReset);
		window.addEventListener('uwbp:reload-recording', onReload);
		window.addEventListener('keydown', onKey);
		refreshFromStorage();
		return () => {
			window.removeEventListener('uwbp:start-demo', onStart);
			window.removeEventListener('uwbp:stop-demo', onStop);
			window.removeEventListener('uwbp:reset-tags', onReset);
			window.removeEventListener('uwbp:reload-recording', onReload);
			window.removeEventListener('keydown', onKey);
		};
	}

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
		const now = Date.now();
		const elapsed = now - replayStartTs;
		for (const d of mockDevices) {
			d.lastSeen = now;
			if (d.type !== 'tag') continue;

			if (replayActive && demoRecording) {
				const next = tagPositionAt(d.id, elapsed);
				if (next) {
					d.position = { ...next };
				}
			}
			// when not active, position stays at last value (start position or last replay frame)

			const noise = 0.005;
			const residual = 0.04 + Math.random() * 0.05;
			const entry = {
				timestamp: now,
				position: {
					x: d.position.x + (Math.random() - 0.5) * noise,
					y: d.position.y + (Math.random() - 0.5) * noise,
					z: d.position.z + (Math.random() - 0.5) * noise
				},
				residual
			};
			if (!mockHistory.has(d.id)) mockHistory.set(d.id, []);
			const arr = mockHistory.get(d.id);
			arr.push(entry);
			const cutoff = now - 60 * 60 * 1000;
			while (arr.length && arr[0].timestamp < cutoff) arr.shift();
		}
	}

	function startMockTicker() {
		mockTickRefcount++;
		if (mockTickHandle) return;
		mockTickHandle = setInterval(mockTick, 50);
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

	export { IS_MOCK, startMockTicker, stopMockTicker, installDemoListeners };
</script>

<script>
	import { setContext, onMount, onDestroy } from 'svelte';

	// ---- props ----
	let { children } = $props();

	// ---- mock lifecycle ----
	if (IS_MOCK) {
		startMockTicker();
		onDestroy(() => stopMockTicker());
	}

	// ---- demo listeners (client-only) ----
	let removeDemoListeners;
	onMount(() => {
		removeDemoListeners = installDemoListeners();
		return () => removeDemoListeners?.();
	});

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
