<script>
	// ---- props ----
	let { children, content, placement = 'top' } = $props();

	// ---- state ----
	let visible = $state(false);
</script>

<span
	class="wrap"
	role="tooltip"
	aria-label={typeof content === 'string' ? content : undefined}
	onmouseenter={() => (visible = true)}
	onmouseleave={() => (visible = false)}
	onfocusin={() => (visible = true)}
	onfocusout={() => (visible = false)}
>
	{@render children()}
	{#if visible}
		<span
			class="tip"
			class:top={placement === 'top'}
			class:bottom={placement === 'bottom'}
			role="status"
		>
			{content}
		</span>
	{/if}
</span>

<style>
	.wrap {
		position: relative;
		display: inline-flex;
	}
	.tip {
		position: absolute;
		left: 50%;
		transform: translateX(-50%);
		padding: var(--space-2) var(--space-3);
		background: var(--bg-tertiary);
		color: var(--text-primary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		font-size: var(--text-xs);
		white-space: nowrap;
		box-shadow: var(--shadow-md);
		z-index: 100;
		pointer-events: none;
	}
	.tip.top {
		bottom: calc(100% + 6px);
	}
	.tip.bottom {
		top: calc(100% + 6px);
	}
</style>
