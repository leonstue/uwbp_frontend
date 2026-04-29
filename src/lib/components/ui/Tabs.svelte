<script>
	// ---- props ----
	let { tabs = [], active = $bindable(''), onchange } = $props();

	function select(id) {
		active = id;
		onchange?.(id);
	}
</script>

<div class="tabs" role="tablist">
	{#each tabs as tab (tab.id)}
		<button
			type="button"
			role="tab"
			class="tab"
			class:active={active === tab.id}
			aria-selected={active === tab.id}
			onclick={() => select(tab.id)}
		>
			{tab.label}
			{#if tab.badge !== undefined}
				<span class="badge">{tab.badge}</span>
			{/if}
		</button>
	{/each}
</div>

<style>
	.tabs {
		display: inline-flex;
		gap: 2px;
		padding: 4px;
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
	}
	.tab {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-3);
		border-radius: var(--radius-sm);
		color: var(--text-secondary);
		font-size: var(--text-sm);
		font-weight: 500;
		transition: background-color 150ms ease, color 150ms ease;
	}
	.tab:hover {
		color: var(--text-primary);
	}
	.tab.active {
		background: var(--bg-tertiary);
		color: var(--accent);
	}
	.badge {
		font-size: var(--text-xs);
		background: var(--bg-tertiary);
		color: var(--text-secondary);
		padding: 1px 6px;
		border-radius: var(--radius-full);
	}
	.tab.active .badge {
		background: var(--accent-glow);
		color: var(--accent);
	}
</style>
