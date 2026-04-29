<script>
	import { getContext } from 'svelte';
	import Sun from 'lucide-svelte/icons/sun';
	import Moon from 'lucide-svelte/icons/moon';

	const app = getContext('app');
</script>

<button
	class="theme-toggle"
	type="button"
	aria-label={app.theme === 'dark' ? 'Helles Theme aktivieren' : 'Dunkles Theme aktivieren'}
	title={app.theme === 'dark' ? 'Helles Theme' : 'Dunkles Theme'}
	onclick={app.toggleTheme}
>
	{#if app.theme === 'dark'}
		<Sun size={18} />
	{:else}
		<Moon size={18} />
	{/if}
</button>

<style>
	.theme-toggle {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--bg-secondary);
		color: var(--text-primary);
		transition: background-color 150ms ease, border-color 150ms ease, color 150ms ease;
	}
	.theme-toggle:hover {
		background: var(--bg-tertiary);
		border-color: var(--border-strong);
		color: var(--accent);
	}
</style>
