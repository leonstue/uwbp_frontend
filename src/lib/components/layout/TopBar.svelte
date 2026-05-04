<script>
	import { page } from '$app/state';
	import { getContext } from 'svelte';
	import ThemeToggle from '../ui/ThemeToggle.svelte';
	import Menu from 'lucide-svelte/icons/menu';
	import X from 'lucide-svelte/icons/x';
	import Radio from 'lucide-svelte/icons/radio';

	// ---- props ----
	let { compact = false } = $props();

	// ---- context ----
	const app = getContext('app');

	// ---- state ----
	let mobileOpen = $state(false);

	// ---- nav config ----
	const links = [
		{ href: '/', label: 'Dashboard' },
		{ href: '/devices', label: 'Geräte' },
		{ href: '/anchors', label: 'Anchors' },
		{ href: '/history', label: 'History' },
		{ href: '/settings', label: 'Einstellungen' }
	];

	function isActive(href) {
		if (href === '/') return page.url.pathname === '/';
		return page.url.pathname.startsWith(href);
	}

	function closeMenu() {
		mobileOpen = false;
	}
</script>

<header class="topbar">
	<div class="inner">
		<a class="brand" href="/" onclick={closeMenu}>
			<Radio size={18} />
			<span>UWBP</span>
		</a>

		{#if !compact}
			<nav class="nav-desktop" aria-label="Hauptnavigation">
				{#each links as link (link.href)}
					<a
						href={link.href}
						class="nav-link"
						class:active={isActive(link.href)}
						aria-current={isActive(link.href) ? 'page' : undefined}
					>
						{link.label}
					</a>
				{/each}
			</nav>
		{/if}

		<div class="actions">
			{#if !compact}
				{@const reason = app.pauseReason}
				{@const running = reason === null}
				{@const label =
					reason === null ? 'Läuft' : reason === 'no-setup' ? 'Pausiert' : 'Gestoppt'}
				<button
					class="status-pill"
					class:running
					class:auto-paused={reason === 'no-setup'}
					type="button"
					onclick={app.toggleRun}
					disabled={reason === 'no-setup'}
					aria-label={running ? 'Live-Ansicht stoppen' : 'Live-Ansicht starten'}
				>
					<span class="dot" class:running class:auto-paused={reason === 'no-setup'}></span>
					<span class="label">{label}</span>
				</button>
			{/if}
			<ThemeToggle />
			{#if !compact}
				<button
					class="hamburger"
					type="button"
					aria-label="Menü öffnen"
					aria-expanded={mobileOpen}
					onclick={() => (mobileOpen = !mobileOpen)}
				>
					{#if mobileOpen}
						<X size={20} />
					{:else}
						<Menu size={20} />
					{/if}
				</button>
			{/if}
		</div>
	</div>

	{#if mobileOpen && !compact}
		<nav class="nav-mobile" aria-label="Mobile Navigation">
			{#each links as link (link.href)}
				<a href={link.href} class="nav-link" class:active={isActive(link.href)} onclick={closeMenu}>
					{link.label}
				</a>
			{/each}
		</nav>
	{/if}
</header>

<style>
	.topbar {
		position: sticky;
		top: 0;
		z-index: 50;
		background: color-mix(in srgb, var(--bg-primary) 85%, transparent);
		backdrop-filter: blur(10px);
		border-bottom: 1px solid var(--border);
	}
	.inner {
		max-width: var(--max-content-width);
		margin: 0 auto;
		padding: var(--space-3) var(--space-4);
		display: flex;
		align-items: center;
		gap: var(--space-4);
	}
	.brand {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		font-weight: 600;
		color: var(--text-primary);
		text-decoration: none;
		letter-spacing: 0.04em;
	}
	.brand:hover {
		color: var(--accent);
	}
	.nav-desktop {
		display: none;
		gap: var(--space-2);
		margin-left: var(--space-4);
	}
	.nav-link {
		padding: var(--space-2) var(--space-3);
		border-radius: var(--radius-md);
		color: var(--text-secondary);
		text-decoration: none;
		font-size: var(--text-sm);
		transition:
			background-color 150ms ease,
			color 150ms ease;
	}
	.nav-link:hover {
		color: var(--text-primary);
		background: var(--bg-secondary);
	}
	.nav-link.active {
		color: var(--accent);
		background: var(--accent-glow);
	}
	.actions {
		margin-left: auto;
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}
	.status-pill {
		display: none;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-2) var(--space-3);
		border: 1px solid var(--border);
		border-radius: var(--radius-full);
		background: var(--bg-secondary);
		color: var(--text-secondary);
		font-size: var(--text-xs);
		font-weight: 500;
	}
	.status-pill.running {
		color: var(--status-online);
		border-color: color-mix(in srgb, var(--status-online) 40%, transparent);
	}
	.status-pill.auto-paused {
		color: var(--status-delayed);
		border-color: color-mix(in srgb, var(--status-delayed) 40%, transparent);
		cursor: default;
		opacity: 0.85;
	}
	.status-pill .dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--text-muted);
	}
	.status-pill .dot.running {
		background: var(--status-online);
		animation: pulse 2s infinite;
	}
	.status-pill .dot.auto-paused {
		background: var(--status-delayed);
	}
	.hamburger {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 36px;
		height: 36px;
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--bg-secondary);
		color: var(--text-primary);
	}
	.nav-mobile {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		padding: var(--space-3) var(--space-4);
		border-top: 1px solid var(--border);
		background: var(--bg-secondary);
	}

	@media (min-width: 768px) {
		.nav-desktop {
			display: flex;
		}
		.status-pill {
			display: inline-flex;
		}
		.hamburger {
			display: none;
		}
	}
</style>
