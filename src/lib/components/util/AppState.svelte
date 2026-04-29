<script>
	import { setContext, getContext, onMount } from 'svelte';
	import Poller from './Poller.svelte';

	// ---- props ----
	let { children } = $props();

	// ---- context: api ----
	const api = getContext('api');

	// ---- env defaults ----
	const POLL_POS_DEFAULT = Number(import.meta.env.VITE_POLL_INTERVAL_POSITIONS ?? 150);
	const POLL_DEV_DEFAULT = Number(import.meta.env.VITE_POLL_INTERVAL_DEVICES ?? 2000);
	const HISTORY_BUFFER_SECONDS_DEFAULT = Number(
		import.meta.env.VITE_HISTORY_BUFFER_SECONDS ?? 600
	);

	// ---- state: data ----
	let devices = $state([]);
	let positions = $state([]);
	let devicesLoading = $state(false);
	let devicesError = $state(null);
	let positionsError = $state(null);
	let serverHealth = $state('unknown');

	// ---- state: ui ----
	let isRunning = $state(true);
	let theme = $state('dark');
	let pollIntervalPositions = $state(POLL_POS_DEFAULT);
	let pollIntervalDevices = $state(POLL_DEV_DEFAULT);
	let historyBufferSeconds = $state(HISTORY_BUFFER_SECONDS_DEFAULT);

	// ---- state: history buffer ----
	let tagHistory = $state(new Map());

	// ---- actions: data ----
	async function fetchDevices() {
		devicesLoading = true;
		try {
			const res = await api.devices.list();
			devices = res.devices ?? [];
			devicesError = null;
		} catch (e) {
			devicesError = String(e?.message ?? e);
		} finally {
			devicesLoading = false;
		}
	}

	async function fetchPositions() {
		try {
			const res = await api.positions.all();
			positions = res.positions ?? [];
			positionsError = null;
			pushHistory(positions);
		} catch (e) {
			positionsError = String(e?.message ?? e);
		}
	}

	async function fetchHealth() {
		try {
			const res = await api.system.health();
			serverHealth = res?.status === 'ok' ? 'ok' : 'down';
		} catch {
			serverHealth = 'down';
		}
	}

	function pushHistory(list) {
		const cutoff = Date.now() - historyBufferSeconds * 1000;
		const next = new Map(tagHistory);
		for (const p of list) {
			const arr = next.get(p.tagId) ?? [];
			arr.push({
				timestamp: p.timestamp,
				position: { ...p.position },
				residual: p.residual
			});
			while (arr.length && arr[0].timestamp < cutoff) arr.shift();
			next.set(p.tagId, arr);
		}
		tagHistory = next;
	}

	function clearHistoryBuffer() {
		tagHistory = new Map();
	}

	// ---- actions: ui ----
	function toggleRun() {
		isRunning = !isRunning;
	}
	function startRun() {
		isRunning = true;
	}
	function stopRun() {
		isRunning = false;
	}

	function setTheme(t) {
		theme = t;
		if (typeof document !== 'undefined') {
			document.documentElement.dataset.theme = t;
		}
		if (typeof localStorage !== 'undefined') {
			localStorage.setItem('uwbp.theme', t);
		}
	}
	function toggleTheme() {
		setTheme(theme === 'dark' ? 'light' : 'dark');
	}

	function persistSetting(key, value) {
		if (typeof localStorage === 'undefined') return;
		localStorage.setItem(`uwbp.${key}`, String(value));
	}

	function setPollIntervalPositions(ms) {
		pollIntervalPositions = ms;
		persistSetting('pollIntervalPositions', ms);
	}
	function setPollIntervalDevices(ms) {
		pollIntervalDevices = ms;
		persistSetting('pollIntervalDevices', ms);
	}
	function setHistoryBufferSeconds(s) {
		historyBufferSeconds = s;
		persistSetting('historyBufferSeconds', s);
	}

	// ---- mount: hydrate from localStorage ----
	onMount(() => {
		try {
			const stored = localStorage.getItem('uwbp.theme');
			if (stored === 'light' || stored === 'dark') {
				setTheme(stored);
			} else if (window.matchMedia?.('(prefers-color-scheme: light)').matches) {
				setTheme('light');
			} else {
				setTheme('dark');
			}
			const pp = Number(localStorage.getItem('uwbp.pollIntervalPositions'));
			if (pp) pollIntervalPositions = pp;
			const pd = Number(localStorage.getItem('uwbp.pollIntervalDevices'));
			if (pd) pollIntervalDevices = pd;
			const hb = Number(localStorage.getItem('uwbp.historyBufferSeconds'));
			if (hb) historyBufferSeconds = hb;
		} catch {
			// ignore
		}
	});

	// ---- context exposure ----
	setContext('app', {
		get devices() {
			return devices;
		},
		get devicesLoading() {
			return devicesLoading;
		},
		get devicesError() {
			return devicesError;
		},
		get positions() {
			return positions;
		},
		get positionsError() {
			return positionsError;
		},
		get anchors() {
			return devices.filter((d) => d.type === 'anchor');
		},
		get tags() {
			return devices.filter((d) => d.type === 'tag');
		},
		get isRunning() {
			return isRunning;
		},
		get theme() {
			return theme;
		},
		get serverHealth() {
			return serverHealth;
		},
		get pollIntervalPositions() {
			return pollIntervalPositions;
		},
		get pollIntervalDevices() {
			return pollIntervalDevices;
		},
		get historyBufferSeconds() {
			return historyBufferSeconds;
		},
		get tagHistory() {
			return tagHistory;
		},
		toggleRun,
		startRun,
		stopRun,
		setTheme,
		toggleTheme,
		setPollIntervalPositions,
		setPollIntervalDevices,
		setHistoryBufferSeconds,
		clearHistoryBuffer,
		refetchDevices: fetchDevices,
		refetchPositions: fetchPositions
	});
</script>

<Poller intervalMs={pollIntervalDevices} onTick={fetchDevices} />
<Poller intervalMs={pollIntervalPositions} enabled={isRunning} onTick={fetchPositions} />
<Poller intervalMs={5000} onTick={fetchHealth} />

{@render children()}
