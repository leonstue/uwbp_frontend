<script>
	import { setContext, getContext, onMount } from 'svelte';
	import { page } from '$app/state';
	import Poller from './Poller.svelte';

	// ---- props ----
	let { children } = $props();

	// ---- context: api ----
	const api = getContext('api');

	// ---- env defaults ----
	const POLL_POS_DEFAULT = Number(import.meta.env.VITE_POLL_INTERVAL_POSITIONS ?? 80);
	const POLL_DEV_DEFAULT = Number(import.meta.env.VITE_POLL_INTERVAL_DEVICES ?? 2000);
	const HISTORY_BUFFER_SECONDS_DEFAULT = Number(import.meta.env.VITE_HISTORY_BUFFER_SECONDS ?? 600);

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

	// ---- state: approved devices (only those registered via wizard) ----
	let approvedDeviceIds = $state(new Set());

	// ---- in-flight guards (prevent stacking when backend is slow) ----
	let devicesInFlight = false;
	let positionsInFlight = false;
	let healthInFlight = false;
	let consecutivePositionFails = 0;

	// ---- actions: data ----
	async function fetchDevices() {
		if (devicesInFlight) return;
		devicesInFlight = true;
		devicesLoading = true;
		try {
			const res = await api.devices.list();
			devices = res.devices ?? [];
			devicesError = null;
		} catch (e) {
			devicesError = String(e?.message ?? e);
		} finally {
			devicesLoading = false;
			devicesInFlight = false;
		}
	}

	async function fetchPositions() {
		if (positionsInFlight) return;
		positionsInFlight = true;
		try {
			const res = await api.positions.all();
			positions = res.positions ?? [];
			positionsError = null;
			consecutivePositionFails = 0;
			pushHistory(positions);
		} catch (e) {
			positionsError = String(e?.message ?? e);
			consecutivePositionFails += 1;
			if (consecutivePositionFails > 3) {
				const backoff = Math.min(2000, 200 * consecutivePositionFails);
				await new Promise((r) => setTimeout(r, backoff));
			}
		} finally {
			positionsInFlight = false;
		}
	}

	async function fetchHealth() {
		if (healthInFlight) return;
		healthInFlight = true;
		try {
			const res = await api.system.health();
			serverHealth = res?.status === 'ok' ? 'ok' : 'down';
		} catch {
			serverHealth = 'down';
		} finally {
			healthInFlight = false;
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

	function persistApproved() {
		if (typeof localStorage === 'undefined') return;
		localStorage.setItem('uwbp.approvedDevices', JSON.stringify([...approvedDeviceIds]));
	}

	function approveDevices(ids) {
		const next = new Set(approvedDeviceIds);
		for (const id of ids) next.add(id);
		approvedDeviceIds = next;
		persistApproved();
	}

	function approveAllCurrent() {
		approveDevices(devices.map((d) => d.id));
	}

	function clearApproved() {
		approvedDeviceIds = new Set();
		persistApproved();
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
			const appr = localStorage.getItem('uwbp.approvedDevices');
			if (appr) {
				try {
					const arr = JSON.parse(appr);
					if (Array.isArray(arr)) approvedDeviceIds = new Set(arr);
				} catch {
					// ignore
				}
			}
		} catch {
			// ignore
		}
	});

	// ---- context exposure ----
	setContext('app', {
		get devices() {
			return devices.filter((d) => approvedDeviceIds.has(d.id));
		},
		get rawDevices() {
			return devices;
		},
		get devicesLoading() {
			return devicesLoading;
		},
		get devicesError() {
			return devicesError;
		},
		get positions() {
			return positions.filter((p) => approvedDeviceIds.has(p.tagId));
		},
		get rawPositions() {
			return positions;
		},
		get positionsError() {
			return positionsError;
		},
		get anchors() {
			return devices.filter((d) => d.type === 'anchor' && approvedDeviceIds.has(d.id));
		},
		get rawAnchors() {
			return devices.filter((d) => d.type === 'anchor');
		},
		get tags() {
			return devices.filter((d) => d.type === 'tag' && approvedDeviceIds.has(d.id));
		},
		get rawTags() {
			return devices.filter((d) => d.type === 'tag');
		},
		get approvedDeviceIds() {
			return approvedDeviceIds;
		},
		get isSetup() {
			return approvedDeviceIds.size > 0;
		},
		get pollingActive() {
			return approvedDeviceIds.size > 0 || page.url.pathname.startsWith('/starten');
		},
		get pauseReason() {
			if (approvedDeviceIds.size === 0 && !page.url.pathname.startsWith('/starten')) {
				return 'no-setup';
			}
			if (!isRunning) return 'manual';
			return null;
		},
		isApproved(id) {
			return approvedDeviceIds.has(id);
		},
		approveDevices,
		approveAllCurrent,
		clearApproved,
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

	let pollingActive = $derived(
		approvedDeviceIds.size > 0 || page.url.pathname.startsWith('/starten')
	);
</script>

<Poller intervalMs={pollIntervalDevices} enabled={pollingActive} onTick={fetchDevices} />
<Poller
	intervalMs={pollIntervalPositions}
	enabled={pollingActive && isRunning}
	onTick={fetchPositions}
/>
<Poller intervalMs={5000} enabled={pollingActive} onTick={fetchHealth} />

{@render children()}
