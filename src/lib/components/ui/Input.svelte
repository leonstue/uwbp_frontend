<script>
	// ---- props ----
	let {
		value = $bindable(''),
		type = 'text',
		label,
		placeholder = '',
		hint,
		error,
		disabled = false,
		readonly = false,
		mono = false,
		min,
		max,
		step,
		onblur,
		onchange,
		oninput,
		...rest
	} = $props();
</script>

<label class="field">
	{#if label}<span class="label">{label}</span>{/if}
	<input
		bind:value
		{type}
		{placeholder}
		{disabled}
		{readonly}
		{min}
		{max}
		{step}
		{onblur}
		{onchange}
		{oninput}
		class="input"
		class:mono
		class:error={!!error}
		{...rest}
	/>
	{#if error}
		<span class="msg error-msg">{error}</span>
	{:else if hint}
		<span class="msg hint">{hint}</span>
	{/if}
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
	.input {
		padding: var(--space-2) var(--space-3);
		background: var(--bg-tertiary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		color: var(--text-primary);
		font-size: var(--text-sm);
		transition: border-color 150ms ease, background-color 150ms ease;
	}
	.input:hover:not(:disabled) {
		border-color: var(--border-strong);
	}
	.input:focus {
		outline: none;
		border-color: var(--accent);
		background: var(--bg-secondary);
	}
	.input:disabled {
		opacity: 0.6;
	}
	.input.mono {
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
	}
	.input.error {
		border-color: var(--status-offline);
	}
	.msg {
		font-size: var(--text-xs);
	}
	.hint {
		color: var(--text-muted);
	}
	.error-msg {
		color: var(--status-offline);
	}
</style>
