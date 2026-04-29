<script>
	import { getContext } from 'svelte';
	import StatusDot from './StatusDot.svelte';

	// ---- context ----
	const app = getContext('app');

	// ---- derived ----
	let healthStatus = $derived(
		app.serverHealth === 'ok' ? 'online' : app.serverHealth === 'down' ? 'offline' : 'delayed'
	);
	let anchorCount = $derived(app.anchors.length);
	let tagCount = $derived(app.tags.length);
</script>

<div class="health">
	<div class="row">
		<StatusDot status={healthStatus} size={8} />
		<span class="lbl">Server</span>
	</div>
	<span class="sep">·</span>
	<span class="stat mono">{anchorCount} Anchors</span>
	<span class="sep">·</span>
	<span class="stat mono">{tagCount} Tags</span>
	<span class="sep">·</span>
	<span class="stat mono">{app.pollIntervalPositions}ms</span>
</div>

<style>
	.health {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-xs);
		color: var(--text-secondary);
		flex-wrap: wrap;
	}
	.row {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.lbl {
		font-weight: 500;
	}
	.sep {
		color: var(--text-muted);
	}
	.stat {
		color: var(--text-secondary);
	}
</style>
