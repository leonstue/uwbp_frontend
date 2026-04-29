<script>
	// ---- props ----
	let { steps = [], current = 0 } = $props();
</script>

<div class="bar" role="progressbar" aria-valuemin="1" aria-valuemax={steps.length} aria-valuenow={current + 1}>
	{#each steps as step, i (i)}
		<div class="step" class:done={i < current} class:active={i === current}>
			<span class="dot">{i + 1}</span>
			<span class="lbl">{step}</span>
		</div>
		{#if i < steps.length - 1}
			<div class="line" class:done={i < current}></div>
		{/if}
	{/each}
</div>

<style>
	.bar {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
	}
	.step {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		color: var(--text-muted);
	}
	.step.active {
		color: var(--accent);
	}
	.step.done {
		color: var(--status-online);
	}
	.dot {
		width: 24px;
		height: 24px;
		border-radius: 50%;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		font-size: var(--text-xs);
		font-weight: 600;
	}
	.step.active .dot {
		border-color: var(--accent);
		background: var(--accent-glow);
	}
	.step.done .dot {
		border-color: var(--status-online);
		background: color-mix(in srgb, var(--status-online) 18%, transparent);
	}
	.lbl {
		font-size: var(--text-xs);
		font-weight: 500;
	}
	.line {
		flex: 1;
		min-width: 12px;
		height: 1px;
		background: var(--border);
	}
	.line.done {
		background: var(--status-online);
	}
	@media (max-width: 640px) {
		.lbl {
			display: none;
		}
	}
</style>
