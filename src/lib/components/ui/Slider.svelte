<script>
	// ---- props ----
	let {
		value = $bindable(0),
		min = 0,
		max = 100,
		step = 1,
		label,
		showValue = true,
		unit = '',
		onchange
	} = $props();
</script>

<label class="field">
	{#if label}
		<span class="label">
			{label}
			{#if showValue}<span class="val mono">{value}{unit}</span>{/if}
		</span>
	{/if}
	<input class="slider" type="range" bind:value {min} {max} {step} {onchange} />
</label>

<style>
	.field {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}
	.label {
		display: flex;
		justify-content: space-between;
		font-size: var(--text-xs);
		color: var(--text-secondary);
		font-weight: 500;
	}
	.val {
		color: var(--text-primary);
	}
	.slider {
		width: 100%;
		appearance: none;
		height: 4px;
		background: var(--border);
		border-radius: var(--radius-full);
		outline: none;
	}
	.slider::-webkit-slider-thumb {
		appearance: none;
		width: 16px;
		height: 16px;
		border-radius: 50%;
		background: var(--accent);
		cursor: pointer;
		border: 2px solid var(--bg-secondary);
		transition: transform 150ms ease;
	}
	.slider::-webkit-slider-thumb:hover {
		transform: scale(1.15);
	}
	.slider::-moz-range-thumb {
		width: 16px;
		height: 16px;
		border-radius: 50%;
		background: var(--accent);
		cursor: pointer;
		border: 2px solid var(--bg-secondary);
	}
</style>
