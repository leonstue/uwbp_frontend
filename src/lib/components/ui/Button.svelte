<script>
	// ---- props ----
	let {
		children,
		variant = 'primary',
		size = 'md',
		type = 'button',
		disabled = false,
		loading = false,
		full = false,
		onclick,
		...rest
	} = $props();
</script>

<button
	{type}
	class="btn"
	class:primary={variant === 'primary'}
	class:secondary={variant === 'secondary'}
	class:ghost={variant === 'ghost'}
	class:danger={variant === 'danger'}
	class:sm={size === 'sm'}
	class:md={size === 'md'}
	class:full
	disabled={disabled || loading}
	{onclick}
	{...rest}
>
	{#if loading}
		<span class="spinner" aria-hidden="true"></span>
	{/if}
	<span class="content"><span class:invisible={loading}>{@render children()}</span></span>
</button>

<style>
	.btn {
		position: relative;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		border-radius: var(--radius-md);
		border: 1px solid transparent;
		font-weight: 500;
		font-size: var(--text-sm);
		line-height: 1;
		transition:
			background-color 150ms ease,
			border-color 150ms ease,
			color 150ms ease,
			opacity 150ms ease;
		cursor: pointer;
		white-space: nowrap;
	}
	.btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}
	.btn.full {
		width: 100%;
	}
	.btn.sm {
		padding: 6px var(--space-3);
		font-size: var(--text-xs);
	}
	.btn.md {
		padding: var(--space-2) var(--space-4);
	}

	.btn.primary {
		background: var(--accent);
		color: #fff;
		border-color: var(--accent);
	}
	.btn.primary:hover:not(:disabled) {
		background: var(--accent-hover);
		border-color: var(--accent-hover);
	}

	.btn.secondary {
		background: var(--bg-secondary);
		color: var(--text-primary);
		border-color: var(--border);
	}
	.btn.secondary:hover:not(:disabled) {
		background: var(--bg-tertiary);
		border-color: var(--border-strong);
	}

	.btn.ghost {
		background: transparent;
		color: var(--text-secondary);
	}
	.btn.ghost:hover:not(:disabled) {
		background: var(--bg-secondary);
		color: var(--text-primary);
	}

	.btn.danger {
		background: var(--status-offline);
		color: #fff;
		border-color: var(--status-offline);
	}
	.btn.danger:hover:not(:disabled) {
		opacity: 0.9;
	}

	.spinner {
		position: absolute;
		width: 14px;
		height: 14px;
		border: 2px solid currentColor;
		border-top-color: transparent;
		border-radius: 50%;
		animation: btn-spin 600ms linear infinite;
	}
	.invisible {
		opacity: 0;
	}

	@keyframes btn-spin {
		to {
			transform: rotate(360deg);
		}
	}
</style>
