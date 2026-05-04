<script>
	// ---- props ----
	let { intervalMs, onTick, enabled = true, immediate = true } = $props();

	// ---- effects ----
	$effect(() => {
		if (!enabled) return;
		let alive = true;
		let timer = 0;

		async function loop() {
			if (immediate) {
				try {
					await onTick();
				} catch {
					// swallow; per-tick errors must not break the loop
				}
			}
			while (alive) {
				const start = performance.now();
				try {
					await onTick();
				} catch {
					// swallow
				}
				if (!alive) break;
				const elapsed = performance.now() - start;
				const delay = Math.max(0, intervalMs - elapsed);
				await new Promise((resolve) => {
					timer = setTimeout(resolve, delay);
				});
			}
		}

		loop();
		return () => {
			alive = false;
			clearTimeout(timer);
		};
	});
</script>
