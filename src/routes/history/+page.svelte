<script>
	import { getContext, untrack, onMount } from 'svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Tabs from '$lib/components/ui/Tabs.svelte';
	import DateRangePicker from '$lib/components/ui/DateRangePicker.svelte';
	import RoomCanvas from '$lib/components/viz/RoomCanvas.svelte';
	import ViewToggle from '$lib/components/viz/ViewToggle.svelte';
	import DeviceColorDot from '$lib/components/device/DeviceColorDot.svelte';
	import Toggle from '$lib/components/ui/Toggle.svelte';
	import PlaybackControls from '$lib/components/util/PlaybackControls.svelte';
	import Download from 'lucide-svelte/icons/download';

	// ---- context ----
	const api = getContext('api');
	const app = getContext('app');
	const toast = getContext('toast');

	// ---- state ----
	let mode = $state('xy');
	let selectedTagIds = $state(new Set());
	let rangePreset = $state('5m');
	let customFrom = $state(null);
	let customTo = $state(null);
	let trailsData = $state(new Map());
	let loading = $state(false);
	let cursorTs = $state(null);
	let playing = $state(false);
	let speed = $state(1);
	let raf = null;
	let lastFrameAt = 0;
	let frozenRange = $state(null);
	let dirty = $state(false);

	// ---- derived ----
	let presetTabs = [
		{ id: '1m', label: '1 min' },
		{ id: '5m', label: '5 min' },
		{ id: '15m', label: '15 min' },
		{ id: '1h', label: '1 h' },
		{ id: 'custom', label: 'Custom' }
	];

	function liveRange() {
		const now = Date.now();
		if (rangePreset === '1m') return { from: now - 60_000, to: now };
		if (rangePreset === '5m') return { from: now - 5 * 60_000, to: now };
		if (rangePreset === '15m') return { from: now - 15 * 60_000, to: now };
		if (rangePreset === '1h') return { from: now - 60 * 60_000, to: now };
		if (rangePreset === 'custom' && customFrom && customTo)
			return { from: customFrom, to: customTo };
		return { from: now - 5 * 60_000, to: now };
	}

	let range = $derived(frozenRange ?? liveRange());

	const TRAIL_MIN_DIST_M = 0.04;

	let trails = $derived.by(() => {
		const out = [];
		const minDistSq = TRAIL_MIN_DIST_M * TRAIL_MIN_DIST_M;
		for (const tag of app.tags) {
			if (!selectedTagIds.has(tag.id)) continue;
			const entries = trailsData.get(tag.id) ?? [];
			const filtered = [];
			let last = null;
			for (const e of entries) {
				if (last) {
					const dx = e.position.x - last.position.x;
					const dy = e.position.y - last.position.y;
					const dz = e.position.z - last.position.z;
					if (dx * dx + dy * dy + dz * dz < minDistSq) continue;
				}
				filtered.push(e);
				last = e;
			}
			out.push({
				tagId: tag.id,
				color: tag.color,
				points: filtered
			});
		}
		return out;
	});

	// ---- actions ----
	function toggleTag(id) {
		const next = new Set(selectedTagIds);
		if (next.has(id)) next.delete(id);
		else next.add(id);
		selectedTagIds = next;
	}

	async function loadTrails() {
		if (!frozenRange) return;
		loading = true;
		try {
			const out = new Map(trailsData);
			const ids = [...selectedTagIds];
			await Promise.all(
				ids.map(async (id) => {
					if (out.has(id)) return;
					try {
						const res = await api.positions.history(id, frozenRange.from, frozenRange.to);
						out.set(id, res.history ?? []);
					} catch (e) {
						toast.push({ type: 'error', message: `History ${id}: ${e.message}` });
					}
				})
			);
			for (const id of [...out.keys()]) {
				if (!selectedTagIds.has(id)) out.delete(id);
			}
			trailsData = out;
		} finally {
			loading = false;
		}
	}

	function exportJson() {
		const payload = Object.fromEntries([...trailsData.entries()]);
		const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
		download(blob, `uwbp-history-${Date.now()}.json`);
	}

	function exportCsv() {
		const rows = [['tagId', 'timestamp', 'x', 'y', 'z', 'residual']];
		for (const [id, list] of trailsData) {
			for (const e of list) {
				rows.push([id, e.timestamp, e.position.x, e.position.y, e.position.z, e.residual]);
			}
		}
		const csv = rows.map((r) => r.join(',')).join('\n');
		download(new Blob([csv], { type: 'text/csv' }), `uwbp-history-${Date.now()}.csv`);
	}

	function download(blob, name) {
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = name;
		a.click();
		URL.revokeObjectURL(url);
	}

	// ---- playback loop ----
	function tick(now) {
		if (!playing) return;
		const dt = lastFrameAt ? now - lastFrameAt : 0;
		lastFrameAt = now;
		cursorTs = Math.min(range.to, (cursorTs ?? range.from) + dt * speed);
		if (cursorTs >= range.to) {
			playing = false;
			lastFrameAt = 0;
			return;
		}
		raf = requestAnimationFrame(tick);
	}

	$effect(() => {
		if (playing) {
			lastFrameAt = 0;
			raf = requestAnimationFrame(tick);
			return () => cancelAnimationFrame(raf);
		}
	});

	$effect(() => {
		void rangePreset;
		void customFrom;
		void customTo;
		dirty = true;
	});

	$effect(() => {
		void selectedTagIds;
		untrack(() => loadTrails());
	});

	function refresh() {
		frozenRange = liveRange();
		dirty = false;
		trailsData = new Map();
		cursorTs = frozenRange.from;
		loadTrails();
	}

	onMount(() => {
		frozenRange = liveRange();
		cursorTs = frozenRange.from;
	});
</script>

<PageHeader title="History" subtitle="Bewegungs-Trails der Tags zeitlich analysieren">
	{#snippet actions()}
		<Button variant={dirty ? 'primary' : 'secondary'} size="sm" onclick={refresh} loading={loading}>
			Aktualisieren
		</Button>
		{#if trailsData.size > 0}
			<Button variant="secondary" size="sm" onclick={exportCsv}>
				<Download size={14} /> CSV
			</Button>
			<Button variant="secondary" size="sm" onclick={exportJson}>
				<Download size={14} /> JSON
			</Button>
		{/if}
	{/snippet}
</PageHeader>

<div class="layout">
	<aside class="filters">
		<Card>
			<div class="grp">
				<span class="lbl">Tags</span>
				<div class="tags">
					{#each app.tags as tag (tag.id)}
						<Toggle
							checked={selectedTagIds.has(tag.id)}
							onchange={() => toggleTag(tag.id)}
							size="sm"
						>
							<DeviceColorDot color={tag.color} />
							<span class="tag-name">{tag.name}</span>
						</Toggle>
					{/each}
					{#if app.tags.length === 0}
						<p class="empty">Keine Tags verfügbar.</p>
					{/if}
				</div>
			</div>
			<div class="grp">
				<span class="lbl">Zeitraum</span>
				<Tabs tabs={presetTabs} bind:active={rangePreset} />
				{#if rangePreset === 'custom'}
					<DateRangePicker bind:from={customFrom} bind:to={customTo} />
				{/if}
			</div>
		</Card>
	</aside>

	<div class="viz">
		<div class="viz-head">
			<ViewToggle bind:mode storageKey="history" allow3d />
		</div>
		<RoomCanvas
			anchors={app.anchors}
			tags={[]}
			{trails}
			{mode}
			{cursorTs}
			showTrailFade={true}
			minHeight={420}
		/>
		<div class="timeline">
			<input
				class="slider"
				type="range"
				min={range.from}
				max={range.to}
				step="100"
				bind:value={cursorTs}
			/>
			<div class="ts mono">
				<span>{new Date(range.from).toLocaleTimeString('de-DE')}</span>
				<span>{cursorTs ? new Date(cursorTs).toLocaleTimeString('de-DE') : '–'}</span>
				<span>{new Date(range.to).toLocaleTimeString('de-DE')}</span>
			</div>
			<PlaybackControls
				bind:playing
				bind:speed
				onStop={() => {
					cursorTs = range.from;
				}}
			/>
		</div>
		{#if loading}
			<p class="status">Lade Trail-Daten …</p>
		{:else if selectedTagIds.size === 0}
			<p class="status">Wähle mindestens einen Tag aus.</p>
		{:else if trails.every((t) => t.points.length === 0)}
			<p class="status">Keine Daten im gewählten Zeitraum.</p>
		{/if}
	</div>
</div>

<style>
	.layout {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-6);
	}
	@media (min-width: 1024px) {
		.layout {
			grid-template-columns: 320px 1fr;
		}
	}
	.filters {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}
	.grp {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}
	.lbl {
		font-size: var(--text-xs);
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--text-muted);
		font-weight: 500;
	}
	.tags {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		max-height: 240px;
		overflow-y: auto;
	}
	.tag-name {
		font-size: var(--text-sm);
	}
	.empty {
		font-size: var(--text-sm);
		color: var(--text-muted);
		margin: 0;
	}
	.viz {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.viz-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.timeline {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
	}
	.slider {
		width: 100%;
	}
	.ts {
		display: flex;
		justify-content: space-between;
		font-size: var(--text-xs);
		color: var(--text-muted);
	}
	.status {
		margin: 0;
		text-align: center;
		color: var(--text-muted);
		font-size: var(--text-sm);
	}
</style>
