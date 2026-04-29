<script>
	// ---- props ----
	let { intervalMs, onTick, enabled = true, immediate = true } = $props();

	// ---- effects ----
	$effect(() => {
		if (!enabled) return;
		if (immediate) onTick();
		const id = setInterval(onTick, intervalMs);
		return () => clearInterval(id);
	});
</script>
