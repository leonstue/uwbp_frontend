<script>
	import { fade, scale } from 'svelte/transition';

	// ---- props ----
	let { open = $bindable(false), title, children, footer, size = 'md', onclose } = $props();

	function close() {
		open = false;
		onclose?.();
	}

	function onKey(e) {
		if (e.key === 'Escape') close();
	}
</script>

<svelte:window onkeydown={onKey} />

{#if open}
	<div
		class="overlay"
		transition:fade={{ duration: 150 }}
		onclick={close}
		onkeydown={(e) => e.key === 'Enter' && close()}
		role="button"
		tabindex="-1"
		aria-label="Dialog schließen"
	>
		<div
			class="dialog"
			class:s-sm={size === 'sm'}
			class:s-md={size === 'md'}
			class:s-lg={size === 'lg'}
			role="dialog"
			aria-modal="true"
			aria-label={title}
			tabindex="-1"
			onclick={(e) => e.stopPropagation()}
			onkeydown={(e) => e.stopPropagation()}
			transition:scale={{ duration: 150, start: 0.96 }}
		>
			{#if title}
				<header class="dialog-header">
					<h2>{title}</h2>
					<button type="button" class="close" aria-label="Schließen" onclick={close}>×</button>
				</header>
			{/if}
			<div class="dialog-body">
				{@render children()}
			</div>
			{#if footer}
				<footer class="dialog-footer">
					{@render footer()}
				</footer>
			{/if}
		</div>
	</div>
{/if}

<style>
	.overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.55);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: var(--space-4);
		z-index: 100;
	}
	.dialog {
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-lg);
		max-height: 90vh;
		overflow: auto;
		display: flex;
		flex-direction: column;
	}
	.s-sm {
		width: 100%;
		max-width: 360px;
	}
	.s-md {
		width: 100%;
		max-width: 520px;
	}
	.s-lg {
		width: 100%;
		max-width: 720px;
	}
	.dialog-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: var(--space-4);
		border-bottom: 1px solid var(--border);
	}
	.dialog-header h2 {
		margin: 0;
		font-size: var(--text-lg);
		font-weight: 500;
	}
	.close {
		font-size: 24px;
		color: var(--text-secondary);
		line-height: 1;
		padding: 0 var(--space-2);
	}
	.close:hover {
		color: var(--text-primary);
	}
	.dialog-body {
		padding: var(--space-4);
	}
	.dialog-footer {
		padding: var(--space-3) var(--space-4);
		border-top: 1px solid var(--border);
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
	}
</style>
