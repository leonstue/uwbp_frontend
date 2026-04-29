<script>
	// ---- props ----
	let { value = $bindable({ x: 0, y: 0, z: 0 }), disabled = false, onchange } = $props();

	function handle(axis, ev) {
		const num = Number(ev.target.value);
		if (Number.isNaN(num)) return;
		value = { ...value, [axis]: num };
		onchange?.(value);
	}
</script>

<div class="row">
	<label class="col">
		<span class="lbl">X</span>
		<input
			type="number"
			step="0.01"
			class="num mono"
			value={value.x}
			oninput={(e) => handle('x', e)}
			{disabled}
			aria-label="X-Koordinate in Metern"
		/>
	</label>
	<label class="col">
		<span class="lbl">Y</span>
		<input
			type="number"
			step="0.01"
			class="num mono"
			value={value.y}
			oninput={(e) => handle('y', e)}
			{disabled}
			aria-label="Y-Koordinate in Metern"
		/>
	</label>
	<label class="col">
		<span class="lbl">Z</span>
		<input
			type="number"
			step="0.01"
			class="num mono"
			value={value.z}
			oninput={(e) => handle('z', e)}
			{disabled}
			aria-label="Z-Koordinate in Metern"
		/>
	</label>
</div>

<style>
	.row {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-2);
	}
	.col {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}
	.lbl {
		font-size: var(--text-xs);
		color: var(--text-muted);
		font-weight: 500;
	}
	.num {
		padding: var(--space-2) var(--space-3);
		background: var(--bg-tertiary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		color: var(--text-primary);
		font-size: var(--text-sm);
		width: 100%;
	}
	.num:hover:not(:disabled) {
		border-color: var(--border-strong);
	}
	.num:focus {
		outline: none;
		border-color: var(--accent);
	}
	.mono {
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
	}
</style>
