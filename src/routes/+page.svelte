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
	import Toggle from '$lib/components/ui/Toggle.svelte';

	// ---- context ----
	const app = getContext('app');

	// ---- state ----
	let mode = $state('xy');
	let didCheckSetup = $state(false);
	let trailEnabled = $state(false);
	let trailWindowSec = $state(3);

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

	const TRAIL_MIN_DIST_M = 0.04;

	let liveTrails = $derived.by(() => {
		if (!trailEnabled) return [];
		const cutoff = Date.now() - trailWindowSec * 1000;
		const minDistSq = TRAIL_MIN_DIST_M * TRAIL_MIN_DIST_M;
		const out = [];
		for (const tag of app.tags) {
			const entries = app.tagHistory.get?.(tag.id) ?? [];
			const filtered = [];
			let last = null;
			for (const e of entries) {
				if (e.timestamp < cutoff) continue;
				if (last) {
					const dx = e.position.x - last.position.x;
					const dy = e.position.y - last.position.y;
					const dz = e.position.z - last.position.z;
					if (dx * dx + dy * dy + dz * dz < minDistSq) continue;
				}
				filtered.push(e);
				last = e;
			}
			if (filtered.length > 1) {
				out.push({ tagId: tag.id, color: tag.color, points: filtered });
			}
		}
		return out;
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
			<span class="lbl">Live</span>
			<div class="head-actions">
				<Toggle bind:checked={trailEnabled} label="Trail anzeigen" size="sm" />
				<ViewToggle bind:mode storageKey="dashboard" allow3d />
			</div>
		</div>
		<RoomCanvas
			anchors={app.anchors}
			tags={app.tags}
			positions={app.positions}
			tagHistory={app.tagHistory}
			trails={liveTrails}
			showTrailFade={true}
			{mode}
			minHeight={460}
		/>
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
	.head-actions {
		display: inline-flex;
		align-items: center;
		gap: var(--space-3);
		flex-wrap: wrap;
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
</style>
