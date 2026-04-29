<script>
	// ---- props ----
	let { children, tone = 'neutral', size = 'md' } = $props();
</script>

<span
	class="badge"
	class:t-neutral={tone === 'neutral'}
	class:t-accent={tone === 'accent'}
	class:t-success={tone === 'success'}
	class:t-warn={tone === 'warn'}
	class:t-danger={tone === 'danger'}
	class:s-sm={size === 'sm'}
	class:s-md={size === 'md'}
>
	{@render children()}
</span>

<style>
	.badge {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		border-radius: var(--radius-full);
		font-weight: 500;
		line-height: 1;
		white-space: nowrap;
		border: 1px solid transparent;
	}
	.s-sm {
		padding: 2px 8px;
		font-size: 11px;
	}
	.s-md {
		padding: 3px 10px;
		font-size: var(--text-xs);
	}
	.t-neutral {
		background: var(--bg-tertiary);
		color: var(--text-secondary);
		border-color: var(--border);
	}
	.t-accent {
		background: var(--accent-glow);
		color: var(--accent);
		border-color: color-mix(in srgb, var(--accent) 35%, transparent);
	}
	.t-success {
		background: color-mix(in srgb, var(--status-online) 18%, transparent);
		color: var(--status-online);
		border-color: color-mix(in srgb, var(--status-online) 40%, transparent);
	}
	.t-warn {
		background: color-mix(in srgb, var(--status-delayed) 18%, transparent);
		color: var(--status-delayed);
		border-color: color-mix(in srgb, var(--status-delayed) 40%, transparent);
	}
	.t-danger {
		background: color-mix(in srgb, var(--status-offline) 18%, transparent);
		color: var(--status-offline);
		border-color: color-mix(in srgb, var(--status-offline) 40%, transparent);
	}
</style>
