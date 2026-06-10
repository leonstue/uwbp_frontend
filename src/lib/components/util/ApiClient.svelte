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
	const DEFAULT_IS_MOCK = !API_BASE && RAW_API_BASE === '';

	// runtime-toggleable demo flag
	let demoModeActive = DEFAULT_IS_MOCK;

	function readPersistedDemo() {
		if (typeof localStorage === 'undefined') return DEFAULT_IS_MOCK;
		const v = localStorage.getItem('uwbp.demoMode');
		if (v === '1') return true;
		if (v === '0') return false;
		return DEFAULT_IS_MOCK;
	}

	function persistDemo(v) {
		if (typeof localStorage === 'undefined') return;
		localStorage.setItem('uwbp.demoMode', v ? '1' : '0');
	}

	demoModeActive = readPersistedDemo();

	function setDemoMode(v) {
		const next = !!v;
		if (next === demoModeActive) return;
		demoModeActive = next;
		persistDemo(next);
		if (typeof window !== 'undefined') {
			window.dispatchEvent(new CustomEvent('uwbp:demo-changed', { detail: { demo: next } }));
		}
	}
	const REQUEST_TIMEOUT_MS = Number(import.meta.env.VITE_REQUEST_TIMEOUT_MS ?? 1500);
	const ONLINE_MS = Number(import.meta.env.VITE_STATUS_ONLINE_THRESHOLD_MS ?? 1000);
	const DELAYED_MS = Number(import.meta.env.VITE_STATUS_DELAYED_THRESHOLD_MS ?? 5000);

	// ---- mock table geometry ----
	const TABLE = { x: 2.0, y: 0.6, z: 0.75 };
	const TAG_1_ID = '24:6F:28:B1:B2:88';
	const TAG_2_ID = '24:6F:28:C0:6A:04';
	const TAG_3_ID = '24:6F:28:7A:9B:0C';
	const TAG_4_ID = '24:6F:28:4F:E8:21';
	const DEFAULT_TAG_1 = { x: 0.5, y: 0.15, z: 0.78 };
	const DEFAULT_TAG_2 = { x: 1.5, y: 0.45, z: 0.78 };
	const DEFAULT_TAG_3 = { x: 1.0, y: 0.3, z: 0.78 };
	const DEFAULT_TAG_4 = { x: 1.0, y: 0.5, z: 0.78 };
	const TAG_IDS_ORDERED = [TAG_1_ID, TAG_2_ID, TAG_3_ID, TAG_4_ID];

	const DEFAULT_TAG_COUNT = 3;
	let mockTagCount = DEFAULT_TAG_COUNT;
	function readTagCount() {
		if (typeof localStorage === 'undefined') return DEFAULT_TAG_COUNT;
		const v = Number(localStorage.getItem('uwbp.mockTagCount'));
		if (Number.isInteger(v) && v >= 1 && v <= 4) return v;
		return DEFAULT_TAG_COUNT;
	}
	mockTagCount = readTagCount();

	function setTagCount(n) {
		const c = Math.max(1, Math.min(4, Number(n) || DEFAULT_TAG_COUNT));
		mockTagCount = c;
		if (typeof localStorage !== 'undefined') {
			localStorage.setItem('uwbp.mockTagCount', String(c));
		}
		if (typeof window !== 'undefined') {
			window.dispatchEvent(new CustomEvent('uwbp:mock-tag-count-changed', { detail: { count: c } }));
		}
	}
	function getTagCount() {
		return mockTagCount;
	}

	// ---- mock state (module-level so generator persists across mounts) ----
	const mockDevices = [
		{
			id: '24:6F:28:6C:5D:48',
			type: 'anchor',
			name: 'Anchor-UL',
			color: '#34D399',
			position: { x: 0, y: 0, z: TABLE.z },
			lastSeen: Date.now()
		},
		{
			id: '24:6F:28:1D:84:40',
			type: 'anchor',
			name: 'Anchor-UR',
			color: '#4F8EFF',
			position: { x: TABLE.x, y: 0, z: TABLE.z },
			lastSeen: Date.now()
		},
		{
			id: '24:6F:28:A2:5F:E2',
			type: 'anchor',
			name: 'Anchor-OR',
			color: '#FBBF24',
			position: { x: TABLE.x, y: TABLE.y, z: TABLE.z },
			lastSeen: Date.now()
		},
		{
			id: '24:6F:28:86:81:40',
			type: 'anchor',
			name: 'Anchor-OL',
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
		},
		{
			id: TAG_3_ID,
			type: 'tag',
			name: 'Tag-Gamma',
			color: '#FB7185',
			position: { ...DEFAULT_TAG_3 },
			lastSeen: Date.now()
		},
		{
			id: TAG_4_ID,
			type: 'tag',
			name: 'Tag-Delta',
			color: '#FCD34D',
			position: { ...DEFAULT_TAG_4 },
			lastSeen: Date.now()
		}
	];

	// snapshot defaults so we can reset
	const DEFAULT_MOCK_DEVICES = JSON.parse(JSON.stringify(mockDevices));

	function saveMockDevices() {
		if (typeof localStorage === 'undefined') return;
		try {
			const minimal = mockDevices.map((d) => ({
				id: d.id,
				name: d.name,
				color: d.color,
				position: d.position
			}));
			localStorage.setItem('uwbp.mockDevices', JSON.stringify(minimal));
		} catch {
			// ignore
		}
	}

	function loadMockDevices() {
		if (typeof localStorage === 'undefined') return;
		try {
			const raw = localStorage.getItem('uwbp.mockDevices');
			if (!raw) return;
			const arr = JSON.parse(raw);
			for (const persisted of arr) {
				const dev = mockDevices.find((d) => d.id === persisted.id);
				if (!dev) continue;
				if (persisted.name) dev.name = persisted.name;
				if (persisted.color) dev.color = persisted.color;
				if (persisted.position) dev.position = { ...persisted.position };
			}
		} catch {
			// ignore
		}
	}

	function saveMockHistoryLocal() {
		if (typeof localStorage === 'undefined') return;
		try {
			const out = {};
			const cutoff = Date.now() - 10 * 60 * 1000;
			for (const [id, arr] of mockHistory) {
				const trimmed = arr.filter((e) => e.timestamp >= cutoff);
				if (trimmed.length) out[id] = trimmed;
			}
			localStorage.setItem('uwbp.mockHistory', JSON.stringify(out));
		} catch {
			// ignore
		}
	}

	function loadMockHistoryLocal() {
		if (typeof localStorage === 'undefined') return;
		try {
			const raw = localStorage.getItem('uwbp.mockHistory');
			if (!raw) return;
			const obj = JSON.parse(raw);
			for (const id of Object.keys(obj)) {
				mockHistory.set(id, obj[id]);
			}
		} catch {
			// ignore
		}
	}

	function resetMockState() {
		for (const def of DEFAULT_MOCK_DEVICES) {
			const dev = mockDevices.find((d) => d.id === def.id);
			if (dev) {
				dev.name = def.name;
				dev.color = def.color;
				dev.position = { ...def.position };
			}
		}
		mockHistory.clear();
		if (typeof localStorage !== 'undefined') {
			localStorage.removeItem('uwbp.mockDevices');
			localStorage.removeItem('uwbp.mockHistory');
		}
	}

	const mockHistory = new Map();
	const mockStartTs = Date.now();

	// hydrate from localStorage
	loadMockDevices();
	loadMockHistoryLocal();
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
			const enabled = localStorage.getItem('uwbp.useDemoRecording');
			if (enabled === '0') return null;
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
		const onVisibility = () => {
			if (document.visibilityState === 'hidden') {
				saveMockHistoryLocal();
			}
		};
		const historyTimer = setInterval(saveMockHistoryLocal, 15000);

		window.addEventListener('uwbp:start-demo', onStart);
		window.addEventListener('uwbp:stop-demo', onStop);
		window.addEventListener('uwbp:reset-tags', onReset);
		window.addEventListener('uwbp:reload-recording', onReload);
		window.addEventListener('keydown', onKey);
		window.addEventListener('visibilitychange', onVisibility);
		window.addEventListener('beforeunload', saveMockHistoryLocal);
		refreshFromStorage();
		return () => {
			clearInterval(historyTimer);
			window.removeEventListener('uwbp:start-demo', onStart);
			window.removeEventListener('uwbp:stop-demo', onStop);
			window.removeEventListener('uwbp:reset-tags', onReset);
			window.removeEventListener('uwbp:reload-recording', onReload);
			window.removeEventListener('keydown', onKey);
			window.removeEventListener('visibilitychange', onVisibility);
			window.removeEventListener('beforeunload', saveMockHistoryLocal);
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

	function perimeterPosition(t) {
		// Rectangle path around the anchors with small inset
		const inset = 0.05;
		const w = TABLE.x - inset * 2;
		const h = TABLE.y - inset * 2;
		const perimeter = 2 * (w + h);
		const speed = 0.35;
		const dist = (t * speed) % perimeter;
		let x;
		let y;
		if (dist < w) {
			x = inset + dist;
			y = inset;
		} else if (dist < w + h) {
			x = inset + w;
			y = inset + (dist - w);
		} else if (dist < 2 * w + h) {
			x = inset + w - (dist - w - h);
			y = inset + h;
		} else {
			x = inset;
			y = inset + h - (dist - 2 * w - h);
		}
		return { x, y, z: 0.8 };
	}

	function circlePosition(seed, t) {
		const phase = (seed % 100) / 50;
		const speed = 0.45 + (seed % 5) / 18;
		const cx = TABLE.x / 2 + (seed % 3 === 0 ? -0.2 : 0.2);
		const cy = TABLE.y / 2;
		const rx = TABLE.x / 4;
		const ry = TABLE.y / 4;
		return {
			x: cx + Math.cos(t * speed + phase) * rx,
			y: cy + Math.sin(t * speed + phase) * ry,
			z: 0.78 + Math.sin(t * speed * 0.5 + phase) * 0.08
		};
	}

	function figureEightPosition(t) {
		const cx = TABLE.x / 2;
		const cy = TABLE.y / 2;
		const ax = TABLE.x / 3;
		const ay = TABLE.y / 3;
		const speed = 0.55;
		const u = t * speed;
		return {
			x: cx + Math.sin(u) * ax,
			y: cy + (Math.sin(u * 2) * ay) / 2,
			z: 0.78 + Math.sin(u * 0.7) * 0.1
		};
	}

	function mockTick() {
		const now = Date.now();
		const elapsed = now - replayStartTs;
		const tSec = (now - mockStartTs) / 1000;
		for (const d of mockDevices) {
			d.lastSeen = now;
			if (d.type !== 'tag') continue;

			const recordable = d.id === TAG_1_ID || d.id === TAG_2_ID;
			const useReplay = recordable && replayActive && demoRecording;

			if (useReplay) {
				const next = tagPositionAt(d.id, elapsed);
				if (next) d.position = { ...next };
			} else if (d.id === TAG_3_ID) {
				d.position = perimeterPosition(tSec);
			} else if (d.id === TAG_4_ID) {
				d.position = figureEightPosition(tSec);
			} else {
				const seed = parseInt(d.id.replace(/[^0-9a-f]/gi, '').slice(-4), 16) || 1;
				d.position = circlePosition(seed, tSec);
			}

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

		const activeTagIds = new Set(TAG_IDS_ORDERED.slice(0, mockTagCount));
		const visibleDevices = mockDevices.filter(
			(d) => d.type !== 'tag' || activeTagIds.has(d.id)
		);

		if (path === '/api/devices' && method === 'GET') {
			return Promise.resolve({ devices: visibleDevices.map(annotateDevice).map(clone) });
		}
		if (path === '/api/anchors' && method === 'GET') {
			return Promise.resolve({
				anchors: visibleDevices
					.filter((d) => d.type === 'anchor')
					.map(annotateDevice)
					.map(clone)
			});
		}
		if (path === '/api/tags' && method === 'GET') {
			return Promise.resolve({
				tags: visibleDevices
					.filter((d) => d.type === 'tag')
					.map(annotateDevice)
					.map(clone)
			});
		}
		if (path === '/api/positions' && method === 'GET') {
			return Promise.resolve({
				positions: visibleDevices
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
				saveMockDevices();
				return Promise.resolve(annotateDevice(clone(mockDevices[idx])));
			}
			if (method === 'DELETE') {
				mockDevices.splice(idx, 1);
				mockHistory.delete(id);
				saveMockDevices();
				return Promise.resolve({ ok: true });
			}
		}

		const matchAnchorPos = path.match(/^\/api\/anchors\/([^/]+)\/position$/);
		if (matchAnchorPos && method === 'PUT') {
			const id = decodeURIComponent(matchAnchorPos[1]);
			const dev = mockDevices.find((d) => d.id === id && d.type === 'anchor');
			if (!dev) return Promise.reject(new Error(`API 404: ${id}`));
			dev.position = { x: Number(body.x), y: Number(body.y), z: Number(body.z) };
			saveMockDevices();
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
		if (demoModeActive) return mockRequest(path, init);
		if (!API_BASE) {
			return Promise.reject(
				new Error('Kein Backend konfiguriert (VITE_API_URL fehlt). Demo-Modus aktivieren.')
			);
		}
		return realRequest(path, init);
	}

	function isDemoActive() {
		return demoModeActive;
	}

	function isRealAvailable() {
		return !!API_BASE;
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

	export {
		DEFAULT_IS_MOCK,
		startMockTicker,
		stopMockTicker,
		installDemoListeners,
		setDemoMode,
		isDemoActive,
		isRealAvailable,
		setTagCount,
		getTagCount,
		resetMockState
	};
</script>

<script>
	import { setContext, onMount, onDestroy } from 'svelte';

	// ---- props ----
	let { children } = $props();

	// ---- reactive mock flag ----
	let demoActive = $state(isDemoActive());
	let tagCount = $state(getTagCount());

	// ---- mock ticker lifecycle (follows demo flag) ----
	let tickerRunning = false;
	$effect(() => {
		if (demoActive && !tickerRunning) {
			startMockTicker();
			tickerRunning = true;
		} else if (!demoActive && tickerRunning) {
			stopMockTicker();
			tickerRunning = false;
		}
	});
	onDestroy(() => {
		if (tickerRunning) stopMockTicker();
	});

	// ---- demo listeners (client-only) ----
	let removeDemoListeners;
	let removeDemoChangedListener;
	onMount(() => {
		removeDemoListeners = installDemoListeners();
		const onChanged = (e) => {
			demoActive = !!e.detail?.demo;
		};
		window.addEventListener('uwbp:demo-changed', onChanged);
		removeDemoChangedListener = () => window.removeEventListener('uwbp:demo-changed', onChanged);
		return () => {
			removeDemoListeners?.();
			removeDemoChangedListener?.();
		};
	});

	function toggleDemo(v) {
		setDemoMode(v);
		demoActive = v;
		if (!v) {
			resetMockState();
		}
	}

	function applyTagCount(n) {
		setTagCount(n);
		tagCount = getTagCount();
	}

	function resetForFreshWizard() {
		resetMockState();
	}

	// ---- context ----
	setContext('api', {
		get isMock() {
			return demoActive;
		},
		get realAvailable() {
			return isRealAvailable();
		},
		get tagCount() {
			return tagCount;
		},
		setDemo: toggleDemo,
		setTagCount: applyTagCount,
		resetMockState: resetForFreshWizard,
		request,
		devices: devicesApi,
		anchors: anchorsApi,
		positions: positionsApi,
		system: systemApi
	});
</script>

{@render children()}
