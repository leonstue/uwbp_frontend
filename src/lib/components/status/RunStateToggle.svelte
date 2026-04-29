<script>
	import { getContext } from 'svelte';
	import Play from 'lucide-svelte/icons/play';
	import Pause from 'lucide-svelte/icons/pause';

	// ---- props ----
	let { showLabel = true } = $props();

	// ---- context ----
	const app = getContext('app');
</script>

<button
	class="toggle"
	type="button"
	class:running={app.isRunning}
	onclick={app.toggleRun}
	aria-label={app.isRunning ? 'Live-Ansicht stoppen' : 'Live-Ansicht starten'}
>
	{#if app.isRunning}
		<Pause size={14} />
	{:else}
		<Play size={14} />
	{/if}
	{#if showLabel}
		<span>{app.isRunning ? 'Läuft' : 'Gestoppt'}</span>
	{/if}
</button>

<style>
	.toggle {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-3);
		border: 1px solid var(--border);
		border-radius: var(--radius-full);
		background: var(--bg-secondary);
		color: var(--text-secondary);
		font-size: var(--text-xs);
		font-weight: 500;
		transition: color 150ms ease, border-color 150ms ease;
	}
	.toggle.running {
		color: var(--status-online);
		border-color: color-mix(in srgb, var(--status-online) 40%, transparent);
	}
	.toggle:hover {
		border-color: var(--border-strong);
	}
</style>
