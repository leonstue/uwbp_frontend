<script>
	// ---- props ----
	let { children, header, footer, padding = 'md', hoverable = false } = $props();
</script>

<div
	class="card"
	class:hoverable
	class:p-sm={padding === 'sm'}
	class:p-md={padding === 'md'}
	class:p-lg={padding === 'lg'}
>
	{#if header}
		<div class="card-header">{@render header()}</div>
	{/if}
	<div class="card-body">{@render children()}</div>
	{#if footer}
		<div class="card-footer">{@render footer()}</div>
	{/if}
</div>

<style>
	.card {
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-lg);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		transition:
			border-color 150ms ease,
			transform 150ms ease;
	}
	.card.hoverable:hover {
		border-color: var(--border-strong);
	}
	.p-sm {
		padding: var(--space-3);
	}
	.p-md {
		padding: var(--space-4);
	}
	.p-lg {
		padding: var(--space-6);
	}
	.card-header {
		font-weight: 500;
		color: var(--text-primary);
		border-bottom: 1px solid var(--border);
		padding-bottom: var(--space-3);
	}
	.card-footer {
		border-top: 1px solid var(--border);
		padding-top: var(--space-3);
	}
	@media (min-width: 768px) {
		.p-md {
			padding: var(--space-6);
		}
	}
</style>
