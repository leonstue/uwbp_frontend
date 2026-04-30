<script>
	import { getContext } from 'svelte';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import HealthIndicator from '$lib/components/status/HealthIndicator.svelte';
	import RoomCanvas from '$lib/components/viz/RoomCanvas.svelte';
	import ViewToggle from '$lib/components/viz/ViewToggle.svelte';
	import StatusDot from '$lib/components/status/StatusDot.svelte';
	import LastSeen from '$lib/components/status/LastSeen.svelte';
	import QualityBadge from '$lib/components/status/QualityBadge.svelte';
	import DeviceColorDot from '$lib/components/device/DeviceColorDot.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import PlaybackControls from '$lib/components/util/PlaybackControls.svelte';
	import History from 'lucide-svelte/icons/history';
	import Radio from 'lucide-svelte/icons/radio';

	// ---- context ----
	const app = getContext('app');

	// ---- state ----
	let mode = $state('xy');
	let didCheckSetup = $state(false);
	let scrubbing = $state(false);
	let cursorTs = $state(null);
	let scrubWindowSec = $state(60);
	let playing = $state(false);
	let speed = $state(1);
	let raf;
	let lastFrameAt = 0;

	// ---- derived ----
	let positionsByTag = $derived.by(() => {
		const map = new Map();
		for (const p of app.positions) map.set(p.tagId, p);
		return map;
	});

	let anchorsConfigured = $derived(
		app.anchors.length > 0 &&
			app.anchors.some((a) => a.position.x !== 0 || a.position.y !== 0 || a.position.z !== 0)
	);

	let sortedDevices = $derived.by(() => {
		const a = [...app.anchors].sort((x, y) => ((x.lastSeen ?? 0) > (y.lastSeen ?? 0) ? -1 : 1));
		const t = [...app.tags].sort((x, y) => ((x.lastSeen ?? 0) > (y.lastSeen ?? 0) ? -1 : 1));
		return [...a, ...t];
	});

	let scrubFrom = $derived(Date.now() - scrubWindowSec * 1000);
	let scrubTo = $derived(Date.now());

	let activeCursor = $derived(scrubbing ? cursorTs : null);

	let scrubbedTagPositions = $derived.by(() => {
		if (!scrubbing || cursorTs === null) return null;
		const out = [];
		for (const tag of app.tags) {
			const entries = app.tagHistory.get?.(tag.id) ?? [];
			let cursor = null;
			for (const e of entries) {
				if (e.timestamp <= cursorTs) cursor = e;
				else break;
			}
			if (cursor) out.push({ tagId: tag.id, position: cursor.position, residual: cursor.residual });
		}
		return out;
	});

	let displayPositions = $derived(scrubbedTagPositions ?? app.positions);

	// ---- actions ----
	function startScrub() {
		scrubbing = true;
		cursorTs = Date.now() - 5000;
	}

	function stopScrub() {
		scrubbing = false;
		playing = false;
		cursorTs = null;
	}

	function tick(now) {
		if (!playing) return;
		const dt = lastFrameAt ? now - lastFrameAt : 0;
		lastFrameAt = now;
		const span = scrubTo - scrubFrom;
		const next = (cursorTs ?? scrubFrom) + dt * speed;
		if (next >= scrubTo) {
			cursorTs = scrubFrom;
		} else {
			cursorTs = next;
		}
		void span;
		raf = requestAnimationFrame(tick);
	}

	$effect(() => {
		if (playing) {
			lastFrameAt = 0;
			raf = requestAnimationFrame(tick);
			return () => cancelAnimationFrame(raf);
		}
	});

	// ---- mount: setup-redirect ----
	onMount(() => {
		setTimeout(() => {
			didCheckSetup = true;
			if (app.devices.length > 0 && app.anchors.length === 0) {
				goto('/setup');
			}
		}, 1500);
	});

	const windowOptions = [
		{ s: 30, label: '30s' },
		{ s: 60, label: '1m' },
		{ s: 300, label: '5m' },
		{ s: 600, label: '10m' }
	];
</script>

<PageHeader title="Dashboard" subtitle="Echtzeit-Übersicht über Anchors und Tags">
	{#snippet actions()}
		<HealthIndicator />
	{/snippet}
</PageHeader>

{#if didCheckSetup && app.anchors.length === 0}
	<Card>
		<div class="cta">
			<p>Noch keine Anchors registriert. Schalte mindestens 3 Anchors ein.</p>
			<Button onclick={() => goto('/setup')}>Setup öffnen</Button>
		</div>
	</Card>
{:else if didCheckSetup && app.anchors.length < 3}
	<Card>
		<p class="warn">
			Brauche mindestens 3 Anchors für Trilateration. Aktuell verbunden: {app.anchors.length}.
		</p>
	</Card>
{:else if didCheckSetup && !anchorsConfigured}
	<Card>
		<div class="cta">
			<p>Anchor-Positionen sind noch nicht konfiguriert.</p>
			<Button onclick={() => goto('/anchors')}>Zur Anchor-Kalibrierung</Button>
		</div>
	</Card>
{/if}

<div class="dash">
	<div class="viz">
		<div class="viz-head">
			<span class="lbl">{scrubbing ? 'Replay' : 'Live'}</span>
			<ViewToggle bind:mode storageKey="dashboard" allow3d />
		</div>
		<RoomCanvas
			anchors={app.anchors}
			tags={app.tags}
			positions={displayPositions}
			tagHistory={app.tagHistory}
			cursorTs={activeCursor}
			{mode}
			minHeight={460}
		/>

		<div class="scrub" class:open={scrubbing}>
			<div class="scrub-head">
				{#if !scrubbing}
					<Button
						variant="secondary"
						size="sm"
						onclick={startScrub}
						disabled={app.tags.length === 0}
					>
						<History size={14} /> Zeitschieber
					</Button>
				{:else}
					<div class="row">
						<span class="lbl">Fenster</span>
						<div class="windows">
							{#each windowOptions as opt (opt.s)}
								<button
									type="button"
									class="win"
									class:active={scrubWindowSec === opt.s}
									onclick={() => (scrubWindowSec = opt.s)}
								>
									{opt.label}
								</button>
							{/each}
						</div>
					</div>
					<Button variant="ghost" size="sm" onclick={stopScrub}>
						<Radio size={14} /> Zurück zu Live
					</Button>
				{/if}
			</div>

			{#if scrubbing}
				<div class="slider-row">
					<input
						class="slider"
						type="range"
						min={scrubFrom}
						max={scrubTo}
						step="100"
						bind:value={cursorTs}
					/>
				</div>
				<div class="ts mono">
					<span>−{scrubWindowSec}s</span>
					<span>
						{cursorTs ? new Date(cursorTs).toLocaleTimeString('de-DE') : '–'}
						<span class="muted">
							(−{Math.max(0, Math.round((Date.now() - (cursorTs ?? Date.now())) / 1000))}s)
						</span>
					</span>
					<span>jetzt</span>
				</div>
				<PlaybackControls
					bind:playing
					bind:speed
					onStop={() => {
						cursorTs = scrubFrom;
					}}
				/>
				<p class="hint">
					Daten kommen aus dem Live-Buffer der letzten {app.historyBufferSeconds}s.
				</p>
			{/if}
		</div>
	</div>

	<aside class="alive">
		<div class="alive-head">
			<span class="lbl">Geräte</span>
			<span class="count">{app.devices.length}</span>
		</div>
		<div class="alive-list">
			{#each sortedDevices as d (d.id)}
				{@const tp = positionsByTag.get(d.id)}
				{@const pos = tp?.position ?? d.position}
				<div class="device">
					<div class="dev-head">
						<StatusDot status={d.status} />
						<DeviceColorDot color={d.color} />
						<span class="name">{d.name}</span>
						{#if d.type === 'tag' && tp?.residual !== undefined}
							<QualityBadge residual={tp.residual} />
						{/if}
					</div>
					<div class="dev-meta">
						<span class="pos mono">
							{pos.x.toFixed(2)}, {pos.y.toFixed(2)}, {pos.z.toFixed(2)}
						</span>
						<LastSeen timestamp={d.lastSeen} />
					</div>
				</div>
			{/each}
			{#if sortedDevices.length === 0}
				<p class="empty">Noch keine Geräte verbunden.</p>
			{/if}
		</div>
	</aside>
</div>

<style>
	.dash {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-6);
	}
	@media (min-width: 1024px) {
		.dash {
			grid-template-columns: 1fr 320px;
			align-items: start;
		}
		.alive {
			position: sticky;
			top: 80px;
		}
	}
	.viz {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.viz-head,
	.alive-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.lbl {
		font-size: var(--text-xs);
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--text-muted);
		font-weight: 500;
	}
	.count {
		font-size: var(--text-xs);
		color: var(--text-muted);
		font-family: var(--font-mono);
	}
	.alive {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.alive-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		max-height: calc(100vh - 200px);
		overflow-y: auto;
	}
	.device {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding: var(--space-3);
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
	}
	.dev-head {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}
	.name {
		flex: 1;
		font-size: var(--text-sm);
		color: var(--text-primary);
		font-weight: 500;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.dev-meta {
		display: flex;
		justify-content: space-between;
		gap: var(--space-2);
		font-size: var(--text-xs);
	}
	.pos {
		color: var(--text-secondary);
	}
	.empty {
		text-align: center;
		color: var(--text-muted);
		font-size: var(--text-sm);
		padding: var(--space-6);
	}
	.cta {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-4);
		flex-wrap: wrap;
	}
	.cta p {
		margin: 0;
		color: var(--text-secondary);
	}
	.warn {
		margin: 0;
		color: var(--status-delayed);
	}
	.scrub {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-3);
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
	}
	.scrub.open {
		border-color: color-mix(in srgb, var(--accent) 35%, var(--border));
	}
	.scrub-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
	}
	.row {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.windows {
		display: inline-flex;
		gap: 2px;
		padding: 2px;
		background: var(--bg-tertiary);
		border-radius: var(--radius-md);
	}
	.win {
		padding: 4px 10px;
		border-radius: var(--radius-sm);
		color: var(--text-secondary);
		font-size: var(--text-xs);
		font-weight: 500;
	}
	.win.active {
		background: var(--bg-secondary);
		color: var(--accent);
	}
	.slider-row {
		display: flex;
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
	.muted {
		color: var(--text-muted);
	}
	.hint {
		margin: 0;
		font-size: 11px;
		color: var(--text-muted);
	}
</style>
