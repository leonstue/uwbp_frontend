<script>
	import { getContext } from 'svelte';
	import { goto } from '$app/navigation';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Slider from '$lib/components/ui/Slider.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import ThemeToggle from '$lib/components/ui/ThemeToggle.svelte';
	import RotateCcw from 'lucide-svelte/icons/rotate-ccw';
	import Trash2 from 'lucide-svelte/icons/trash-2';
	import Power from 'lucide-svelte/icons/power';
	import StopCircle from 'lucide-svelte/icons/stop-circle';

	// ---- context ----
	const app = getContext('app');
	const api = getContext('api');
	const toast = getContext('toast');

	// ---- state ----
	let endpoints = $state([]);
	let advancedOpen = $state(false);
	let shutdownConfirm = $state(false);
	let pollPos = $state(app.pollIntervalPositions);
	let pollDev = $state(app.pollIntervalDevices);
	let bufSec = $state(app.historyBufferSeconds);

	// ---- effects ----
	$effect(() => {
		api.system
			.routes()
			.then((r) => (endpoints = r?.endpoints ?? []))
			.catch(() => (endpoints = []));
	});

	// ---- actions ----
	function applyPollPos() {
		app.setPollIntervalPositions(Number(pollPos));
	}
	function applyPollDev() {
		app.setPollIntervalDevices(Number(pollDev));
	}
	function applyBuf() {
		app.setHistoryBufferSeconds(Number(bufSec));
	}

	async function shutdownServer() {
		try {
			await api.system.shutdown();
			toast.push({ type: 'warn', message: 'Shutdown angefordert' });
		} catch (e) {
			toast.push({ type: 'error', message: 'Fehler: ' + e.message });
		}
	}
</script>

<PageHeader title="Einstellungen" subtitle="System-Konfiguration und Präferenzen" />

<div class="grid">
	<Card>
		{#snippet header()}<span>Polling</span>{/snippet}
		<div class="col">
			<Slider
				label="Position-Updates"
				bind:value={pollPos}
				min={50}
				max={500}
				step={10}
				unit="ms"
				onchange={applyPollPos}
			/>
			<Slider
				label="Geräte-Updates"
				bind:value={pollDev}
				min={1000}
				max={5000}
				step={100}
				unit="ms"
				onchange={applyPollDev}
			/>
		</div>
	</Card>

	<Card>
		{#snippet header()}<span>History</span>{/snippet}
		<div class="col">
			<Slider
				label="Buffer-Größe"
				bind:value={bufSec}
				min={60}
				max={3600}
				step={30}
				unit=" s"
				onchange={applyBuf}
			/>
			<div class="row-end">
				<Button variant="secondary" size="sm" onclick={app.clearHistoryBuffer}>
					<Trash2 size={14} /> Buffer leeren
				</Button>
			</div>
		</div>
	</Card>

	<Card>
		{#snippet header()}<span>Darstellung</span>{/snippet}
		<div class="row-between">
			<div>
				<div class="lbl">Theme</div>
				<div class="muted">Aktuell: {app.theme === 'dark' ? 'Dunkel' : 'Hell'}</div>
			</div>
			<ThemeToggle />
		</div>
	</Card>

	<Card>
		{#snippet header()}<span>Netzwerk</span>{/snippet}
		<dl class="kv-list">
			<div>
				<dt>WLAN</dt>
				<dd class="mono">UWBP</dd>
			</div>
			<div>
				<dt>Passwort</dt>
				<dd class="mono">abcd1234</dd>
			</div>
			<div>
				<dt>Pi-IP</dt>
				<dd class="mono">10.42.0.1</dd>
			</div>
			<div>
				<dt>Hostname</dt>
				<dd class="mono">uwbp</dd>
			</div>
			<div>
				<dt>Modus</dt>
				<dd class="mono">{api.isMock ? 'Mock' : 'Live'}</dd>
			</div>
		</dl>
	</Card>

	<Card>
		{#snippet header()}<span>System</span>{/snippet}
		<div class="col">
			<div class="row-between">
				<span>Wizard „Starten" erneut öffnen</span>
				<Button variant="secondary" size="sm" onclick={() => goto('/starten')}>
					<RotateCcw size={14} /> Öffnen
				</Button>
			</div>
			<div class="row-between">
				<span>Geräte-Freigabe zurücksetzen</span>
				<Button variant="secondary" size="sm" onclick={app.clearApproved}>
					<Trash2 size={14} /> Zurücksetzen
				</Button>
			</div>
			<div class="row-between">
				<span>Live-Ansicht beenden</span>
				<Button variant="secondary" size="sm" onclick={app.stopRun} disabled={!app.isRunning}>
					<StopCircle size={14} /> Stoppen
				</Button>
			</div>
		</div>
	</Card>

	<Card>
		{#snippet header()}<span>API-Endpoints</span>{/snippet}
		<ul class="ep-list mono">
			{#each endpoints as ep (ep)}
				<li>{ep}</li>
			{/each}
			{#if endpoints.length === 0}
				<li class="muted">Keine Endpoints geladen.</li>
			{/if}
		</ul>
	</Card>

	<Card>
		{#snippet header()}
			<button class="adv-head" type="button" onclick={() => (advancedOpen = !advancedOpen)}>
				<span>Erweitert</span>
				<span class="muted">{advancedOpen ? '−' : '+'}</span>
			</button>
		{/snippet}
		{#if advancedOpen}
			<div class="warn-box">
				<p>
					<strong>Achtung:</strong> Server-Shutdown beendet den Backend-Prozess auf dem Pi. Das WLAN bricht
					ab und das System muss manuell neu gestartet werden.
				</p>
				<Button variant="danger" size="sm" onclick={() => (shutdownConfirm = true)}>
					<Power size={14} /> Server beenden
				</Button>
			</div>
		{/if}
	</Card>
</div>

<ConfirmDialog
	bind:open={shutdownConfirm}
	title="Server beenden?"
	message="Der Backend-Server wird gestoppt. Du verlierst die Verbindung."
	confirmLabel="Beenden"
	variant="danger"
	onConfirm={shutdownServer}
/>

<style>
	.grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-4);
	}
	@media (min-width: 768px) {
		.grid {
			grid-template-columns: 1fr 1fr;
		}
	}
	.col {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.row-between {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-3);
		flex-wrap: wrap;
	}
	.row-end {
		display: flex;
		justify-content: flex-end;
	}
	.lbl {
		font-weight: 500;
	}
	.muted {
		color: var(--text-muted);
		font-size: var(--text-xs);
	}
	.kv-list {
		margin: 0;
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-2);
	}
	.kv-list > div {
		display: flex;
		justify-content: space-between;
	}
	.kv-list dt {
		color: var(--text-muted);
		font-size: var(--text-sm);
	}
	.kv-list dd {
		margin: 0;
		color: var(--text-primary);
		font-size: var(--text-sm);
	}
	.ep-list {
		margin: 0;
		padding: 0;
		list-style: none;
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		font-size: var(--text-xs);
		color: var(--text-secondary);
		max-height: 220px;
		overflow-y: auto;
	}
	.adv-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		width: 100%;
		font-weight: 500;
	}
	.warn-box {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.warn-box p {
		margin: 0;
		font-size: var(--text-sm);
		color: var(--text-secondary);
		line-height: 1.5;
	}
</style>
