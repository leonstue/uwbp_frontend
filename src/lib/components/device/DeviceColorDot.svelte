<script>
	// ---- props ----
	let { color = '#4F8EFF', size = 10, label } = $props();
</script>

<span class="dot" style:--dot-color={color} style:--dot-size="{size}px" aria-label={label} title={label}></span>

<style>
	.dot {
		display: inline-block;
		width: var(--dot-size);
		height: var(--dot-size);
		border-radius: 50%;
		background: var(--dot-color);
		box-shadow: 0 0 0 2px var(--bg-secondary);
		flex-shrink: 0;
	}
</style>
