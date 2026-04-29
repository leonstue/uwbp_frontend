<script>
	import { setContext } from 'svelte';
	import Toast from './Toast.svelte';

	// ---- props ----
	let { children } = $props();

	// ---- state ----
	let toasts = $state([]);
	let nextId = 0;

	function push({ type = 'info', message, durationMs = 4000 }) {
		const id = ++nextId;
		toasts = [...toasts, { id, type, message }];
		if (durationMs > 0) {
			setTimeout(() => dismiss(id), durationMs);
		}
		return id;
	}
	function dismiss(id) {
		toasts = toasts.filter((t) => t.id !== id);
	}

	setContext('toast', { push, dismiss });
</script>

{@render children()}

<div class="host" aria-live="polite">
	{#each toasts as t (t.id)}
		<Toast type={t.type} message={t.message} onclose={() => dismiss(t.id)} />
	{/each}
</div>

<style>
	.host {
		position: fixed;
		bottom: var(--space-4);
		right: var(--space-4);
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		z-index: 200;
	}
	@media (max-width: 480px) {
		.host {
			left: var(--space-4);
			right: var(--space-4);
		}
	}
</style>
