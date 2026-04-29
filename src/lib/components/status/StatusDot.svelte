<script>
	// ---- props ----
	let { status = 'offline', size = 8, label } = $props();

	// ---- derived ----
	let text = $derived(
		status === 'online' ? 'Online' : status === 'delayed' ? 'Verzögert' : 'Offline'
	);
</script>

<span class="wrap" aria-label={label ?? text} title={label ?? text}>
	<span
		class="dot"
		class:online={status === 'online'}
		class:delayed={status === 'delayed'}
		class:offline={status === 'offline'}
		style:--size="{size}px"
	></span>
	<span class="sr-only">{text}</span>
</span>

<style>
	.wrap {
		display: inline-flex;
		align-items: center;
	}
	.dot {
		width: var(--size);
		height: var(--size);
		border-radius: 50%;
		background: var(--text-muted);
		flex-shrink: 0;
	}
	.dot.online {
		background: var(--status-online);
		animation: pulse 2s infinite;
	}
	.dot.delayed {
		background: var(--status-delayed);
	}
	.dot.offline {
		background: var(--status-offline);
	}
</style>
