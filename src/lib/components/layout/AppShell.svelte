<script>
	import { getContext } from 'svelte';
	import TopBar from './TopBar.svelte';

	// ---- props ----
	let { children, compact = false } = $props();

	// ---- context ----
	const app = getContext('app');
</script>

<div class="shell">
	<TopBar {compact} />

	{#if app.serverHealth === 'down'}
		<div class="banner banner-error" role="alert">
			Verbindung zum Pi verloren — prüfe die WLAN-Verbindung zum Netzwerk „UWBP".
		</div>
	{/if}

	{#if !app.isRunning && !compact}
		<div class="banner banner-info">
			Live-Ansicht pausiert. Daten werden weiter im Hintergrund vom Server gesammelt.
		</div>
	{/if}

	<main class="main">
		<div class="content">
			{@render children()}
		</div>
	</main>
</div>

<style>
	.shell {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		background: var(--bg-primary);
	}
	.main {
		flex: 1;
		width: 100%;
	}
	.content {
		max-width: var(--max-content-width);
		margin: 0 auto;
		padding: var(--space-6) var(--space-4);
	}
	.banner {
		max-width: var(--max-content-width);
		margin: var(--space-3) auto 0;
		padding: var(--space-3) var(--space-4);
		border-radius: var(--radius-md);
		font-size: var(--text-sm);
	}
	.banner-error {
		background: color-mix(in srgb, var(--status-offline) 18%, var(--bg-secondary));
		border: 1px solid color-mix(in srgb, var(--status-offline) 50%, transparent);
		color: var(--status-offline);
	}
	.banner-info {
		background: color-mix(in srgb, var(--accent) 12%, var(--bg-secondary));
		border: 1px solid color-mix(in srgb, var(--accent) 35%, transparent);
		color: var(--text-secondary);
	}
</style>
