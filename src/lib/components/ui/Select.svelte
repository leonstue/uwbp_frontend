<script>
	// ---- props ----
	let { value = $bindable(''), options = [], label, disabled = false, onchange } = $props();
</script>

<label class="field">
	{#if label}<span class="label">{label}</span>{/if}
	<select bind:value class="select" {disabled} {onchange}>
		{#each options as opt (opt.value)}
			<option value={opt.value}>{opt.label}</option>
		{/each}
	</select>
</label>

<style>
	.field {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}
	.label {
		font-size: var(--text-xs);
		color: var(--text-secondary);
		font-weight: 500;
	}
	.select {
		padding: var(--space-2) var(--space-3);
		background: var(--bg-tertiary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		color: var(--text-primary);
		font-size: var(--text-sm);
		cursor: pointer;
	}
	.select:hover {
		border-color: var(--border-strong);
	}
	.select:focus {
		outline: none;
		border-color: var(--accent);
	}
</style>
