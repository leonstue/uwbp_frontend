<script>
	// ---- props ----
	let { value = $bindable('#4F8EFF'), label, onchange } = $props();
</script>

<label class="picker">
	{#if label}<span class="lbl">{label}</span>{/if}
	<span class="row">
		<input type="color" bind:value class="color-input" {onchange} aria-label="Farbe wählen" />
		<span class="hex mono">{value}</span>
	</span>
</label>

<style>
	.picker {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}
	.lbl {
		font-size: var(--text-xs);
		color: var(--text-secondary);
		font-weight: 500;
	}
	.row {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.color-input {
		width: 32px;
		height: 32px;
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		cursor: pointer;
		padding: 2px;
		background: var(--bg-tertiary);
	}
	.hex {
		font-size: var(--text-xs);
		color: var(--text-secondary);
		text-transform: uppercase;
	}
</style>
