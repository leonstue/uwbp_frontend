<script>
	import Badge from '../ui/Badge.svelte';

	// ---- props ----
	let { residual } = $props();

	// ---- derived ----
	let tone = $derived(
		residual === undefined
			? 'neutral'
			: residual < 0.2
				? 'success'
				: residual < 0.5
					? 'warn'
					: 'danger'
	);
	let label = $derived(residual === undefined ? '–' : residual.toFixed(2) + 'm');
</script>

<Badge {tone} size="sm">
	<span class="mono">{label}</span>
</Badge>

<style>
	.mono {
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
	}
</style>
