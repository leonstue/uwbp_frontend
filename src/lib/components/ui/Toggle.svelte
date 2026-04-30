<script>
	// ---- props ----
	let {
		checked = $bindable(false),
		label,
		children,
		disabled = false,
		size = 'md',
		onchange,
		...rest
	} = $props();

	function handle(e) {
		checked = e.currentTarget.checked;
		onchange?.(checked);
	}
</script>

<label class="toggle" class:disabled class:s-sm={size === 'sm'} class:s-md={size === 'md'}>
	<input
		type="checkbox"
		role="switch"
		{disabled}
		checked={checked}
		onchange={handle}
		{...rest}
	/>
	<span class="track" aria-hidden="true">
		<span class="thumb"></span>
	</span>
	{#if children}
		<span class="content">{@render children()}</span>
	{:else if label}
		<span class="lbl">{label}</span>
	{/if}
</label>

<style>
	.toggle {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		cursor: pointer;
		user-select: none;
		font-size: var(--text-sm);
		color: var(--text-primary);
	}
	.toggle.disabled {
		cursor: not-allowed;
		opacity: 0.5;
	}
	.toggle input {
		position: absolute;
		opacity: 0;
		width: 0;
		height: 0;
	}
	.track {
		position: relative;
		display: inline-block;
		flex-shrink: 0;
		background: var(--bg-tertiary);
		border: 1px solid var(--border);
		border-radius: var(--radius-full);
		transition:
			background-color 200ms ease,
			border-color 200ms ease;
	}
	.s-sm .track {
		width: 30px;
		height: 18px;
	}
	.s-md .track {
		width: 38px;
		height: 22px;
	}
	.thumb {
		position: absolute;
		top: 50%;
		left: 2px;
		transform: translateY(-50%);
		background: var(--text-secondary);
		border-radius: 50%;
		box-shadow: 0 1px 2px rgba(0, 0, 0, 0.25);
		transition:
			left 220ms cubic-bezier(0.4, 0, 0.2, 1),
			background-color 200ms ease,
			width 200ms ease;
	}
	.s-sm .thumb {
		width: 12px;
		height: 12px;
	}
	.s-md .thumb {
		width: 16px;
		height: 16px;
	}

	.toggle input:checked + .track {
		background: var(--accent);
		border-color: var(--accent);
	}
	.toggle input:checked + .track .thumb {
		background: #fff;
	}
	.s-sm input:checked + .track .thumb {
		left: calc(100% - 14px);
	}
	.s-md input:checked + .track .thumb {
		left: calc(100% - 18px);
	}

	.toggle input:focus-visible + .track {
		outline: 2px solid var(--accent);
		outline-offset: 2px;
	}
	.toggle:hover:not(.disabled) .track {
		border-color: var(--border-strong);
	}
	.toggle:active:not(.disabled) .thumb {
		width: 22px;
	}
	.s-sm:active:not(.disabled) .thumb {
		width: 16px;
	}

	.lbl {
		font-weight: 500;
	}
	.content {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
</style>
