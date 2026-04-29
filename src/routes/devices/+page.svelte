<script>
	import { getContext } from 'svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import Tabs from '$lib/components/ui/Tabs.svelte';
	import DeviceList from '$lib/components/device/DeviceList.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import ConfirmDialog from '$lib/components/ui/ConfirmDialog.svelte';
	import HealthIndicator from '$lib/components/status/HealthIndicator.svelte';

	// ---- context ----
	const app = getContext('app');
	const api = getContext('api');
	const toast = getContext('toast');

	// ---- state ----
	let filter = $state('all');
	let savingIds = $state(new Set());
	let confirmOpen = $state(false);
	let pendingRemoveId = $state(null);

	// ---- derived ----
	let tabs = $derived([
		{ id: 'all', label: 'Alle', badge: app.devices.length },
		{ id: 'anchor', label: 'Anchors', badge: app.anchors.length },
		{ id: 'tag', label: 'Tags', badge: app.tags.length }
	]);

	let filtered = $derived(
		filter === 'all' ? app.devices : app.devices.filter((d) => d.type === filter)
	);

	// ---- actions ----
	async function handleSave(id, data) {
		savingIds = new Set([...savingIds, id]);
		try {
			await api.devices.update(id, data);
			toast.push({ type: 'success', message: 'Gespeichert' });
			app.refetchDevices();
		} catch (e) {
			toast.push({ type: 'error', message: 'Speichern fehlgeschlagen: ' + e.message });
		} finally {
			savingIds = new Set([...savingIds].filter((x) => x !== id));
		}
	}

	function askRemove(id) {
		pendingRemoveId = id;
		confirmOpen = true;
	}

	async function confirmRemove() {
		if (!pendingRemoveId) return;
		try {
			await api.devices.remove(pendingRemoveId);
			toast.push({ type: 'success', message: 'Gerät entfernt' });
			app.refetchDevices();
		} catch (e) {
			toast.push({ type: 'error', message: 'Entfernen fehlgeschlagen: ' + e.message });
		} finally {
			pendingRemoveId = null;
		}
	}
</script>

<PageHeader title="Geräte" subtitle="Alle registrierten ESP32-Devices verwalten">
	{#snippet actions()}
		<HealthIndicator />
	{/snippet}
</PageHeader>

<div class="toolbar">
	<Tabs {tabs} bind:active={filter} />
</div>

{#if app.devicesError}
	<Card>
		<p class="error">Fehler beim Laden: {app.devicesError}</p>
	</Card>
{:else if app.devices.length === 0}
	<Card>
		<p class="empty">
			Noch keine Geräte registriert. Schalte deine Anchors und Tags ein und prüfe die WLAN-Verbindung
			zum Pi.
		</p>
	</Card>
{:else}
	<DeviceList devices={filtered} {savingIds} onSave={handleSave} onRemove={askRemove} />
{/if}

<ConfirmDialog
	bind:open={confirmOpen}
	title="Gerät vergessen?"
	message="Das Gerät wird aus der Liste entfernt. Beim nächsten Einschalten registriert es sich neu."
	confirmLabel="Vergessen"
	variant="danger"
	onConfirm={confirmRemove}
/>

<style>
	.toolbar {
		margin-bottom: var(--space-4);
	}
	.empty,
	.error {
		margin: 0;
		color: var(--text-secondary);
		font-size: var(--text-sm);
	}
	.error {
		color: var(--status-offline);
	}
</style>
