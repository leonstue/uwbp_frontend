<script>
	import StatusDot from '../status/StatusDot.svelte';
	import LastSeen from '../status/LastSeen.svelte';
	import QualityBadge from '../status/QualityBadge.svelte';
	import DeviceColorDot from './DeviceColorDot.svelte';
	import Badge from '../ui/Badge.svelte';

	// ---- props ----
	let { device, residual, compact = false } = $props();

	// ---- derived ----
	let posLabel = $derived(
		device?.position
			? `${device.position.x.toFixed(2)}, ${device.position.y.toFixed(2)}, ${device.position.z.toFixed(2)}`
			: '–'
	);
</script>

<article class="device" class:compact>
	<header class="head">
		<div class="row-left">
			<StatusDot status={device.status} size={8} />
			<DeviceColorDot color={device.color} />
			<span class="name">{device.name}</span>
		</div>
		<Badge tone={device.type === 'anchor' ? 'accent' : 'neutral'} size="sm">
			{device.type === 'anchor' ? 'Anchor' : 'Tag'}
		</Badge>
	</header>

	<div class="meta">
		<span class="kv">
			<span class="k">Position</span>
			<span class="v mono">{posLabel}</span>
		</span>
		<span class="kv">
			<span class="k">Letzter Kontakt</span>
			<LastSeen timestamp={device.lastSeen} />
		</span>
		{#if device.type === 'tag' && residual !== undefined}
			<span class="kv">
				<span class="k">Qualität</span>
				<QualityBadge {residual} />
			</span>
		{/if}
		<span class="kv id">
			<span class="k">ID</span>
			<span class="v mono small">{device.id}</span>
		</span>
	</div>
</article>

<style>
	.device {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-4);
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-lg);
	}
	.device.compact {
		padding: var(--space-3);
		gap: var(--space-2);
	}
	.head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-2);
	}
	.row-left {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		min-width: 0;
	}
	.name {
		font-weight: 500;
		color: var(--text-primary);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.meta {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}
	.kv {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-3);
		font-size: var(--text-xs);
	}
	.k {
		color: var(--text-muted);
	}
	.v {
		color: var(--text-primary);
	}
	.small {
		font-size: 11px;
		color: var(--text-secondary);
	}
</style>
