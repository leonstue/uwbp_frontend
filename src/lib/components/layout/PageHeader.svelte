<script>
	// ---- props ----
	let { title, subtitle, actions } = $props();
</script>

<header class="page-header">
	<div class="text">
		<h1>{title}</h1>
		{#if subtitle}
			<p class="subtitle">{subtitle}</p>
		{/if}
	</div>
	{#if actions}
		<div class="actions">
			{@render actions()}
		</div>
	{/if}
</header>

<style>
	.page-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: var(--space-4);
		margin-bottom: var(--space-6);
		flex-wrap: wrap;
	}
	h1 {
		margin: 0;
		font-size: var(--text-2xl);
		font-weight: 600;
		letter-spacing: -0.01em;
		color: var(--text-primary);
	}
	.subtitle {
		margin: var(--space-1) 0 0;
		color: var(--text-secondary);
		font-size: var(--text-sm);
	}
	.actions {
		display: flex;
		gap: var(--space-2);
		align-items: center;
	}
</style>
