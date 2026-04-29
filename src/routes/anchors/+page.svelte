<script>
	import { getContext } from 'svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Modal from '$lib/components/ui/Modal.svelte';
	import Input from '$lib/components/ui/Input.svelte';
	import StatusDot from '$lib/components/status/StatusDot.svelte';
	import DeviceColorDot from '$lib/components/device/DeviceColorDot.svelte';
	import PositionInput from '$lib/components/device/PositionInput.svelte';
	import RoomCanvas from '$lib/components/viz/RoomCanvas.svelte';
	import ViewToggle from '$lib/components/viz/ViewToggle.svelte';
	import Save from 'lucide-svelte/icons/save';
	import LayoutTemplate from 'lucide-svelte/icons/layout-template';

	// ---- context ----
	const app = getContext('app');
	const api = getContext('api');
	const toast = getContext('toast');

	// ---- state ----
	let drafts = $state(new Map());
	let savingIds = $state(new Set());
	let mode = $state('xy');
	let templateOpen = $state(false);
	let templateKind = $state('rect');
	let roomW = $state(5);
	let roomD = $state(4);
	let roomH = $state(2.5);

	// ---- effects ----
	$effect(() => {
		const next = new Map(drafts);
		for (const a of app.anchors) {
			if (!next.has(a.id)) {
				next.set(a.id, { ...a.position });
			}
		}
		for (const id of next.keys()) {
			if (!app.anchors.find((a) => a.id === id)) next.delete(id);
		}
		drafts = next;
	});

	// ---- derived ----
	let previewAnchors = $derived(
		app.anchors.map((a) => ({ ...a, position: drafts.get(a.id) ?? a.position }))
	);

	let duplicates = $derived.by(() => {
		const seen = new Map();
		const dupes = new Set();
		for (const [id, pos] of drafts) {
			const key = `${pos.x.toFixed(3)}|${pos.y.toFixed(3)}|${pos.z.toFixed(3)}`;
			if (seen.has(key)) {
				dupes.add(id);
				dupes.add(seen.get(key));
			} else {
				seen.set(key, id);
			}
		}
		return dupes;
	});

	// ---- actions ----
	function updateDraft(id, pos) {
		const next = new Map(drafts);
		next.set(id, pos);
		drafts = next;
	}

	async function saveAnchor(id) {
		const pos = drafts.get(id);
		if (!pos) return;
		savingIds = new Set([...savingIds, id]);
		try {
			await api.anchors.setPosition(id, pos.x, pos.y, pos.z);
			toast.push({ type: 'success', message: 'Position gespeichert' });
			app.refetchDevices();
		} catch (e) {
			toast.push({ type: 'error', message: 'Fehler: ' + e.message });
		} finally {
			savingIds = new Set([...savingIds].filter((x) => x !== id));
		}
	}

	function applyTemplate() {
		const list = app.anchors;
		if (list.length === 0) return;
		const corners =
			templateKind === 'rect'
				? [
						{ x: 0, y: 0, z: roomH },
						{ x: roomW, y: 0, z: roomH },
						{ x: roomW, y: roomD, z: roomH },
						{ x: 0, y: roomD, z: roomH }
					]
				: [
						{ x: 0, y: 0, z: roomH },
						{ x: roomW, y: 0, z: roomH },
						{ x: roomW / 2, y: roomD, z: roomH }
					];
		const next = new Map(drafts);
		list.forEach((a, i) => {
			const c = corners[i % corners.length];
			next.set(a.id, { ...c });
		});
		drafts = next;
		templateOpen = false;
		toast.push({ type: 'info', message: 'Vorlage übernommen — noch nicht gespeichert' });
	}
</script>

<PageHeader
	title="Anchor-Kalibrierung"
	subtitle="X = Breite, Y = Tiefe, Z = Höhe — alles in Metern, Ursprung im Raumeck"
>
	{#snippet actions()}
		<Button variant="secondary" size="sm" onclick={() => (templateOpen = true)}>
			<LayoutTemplate size={14} /> Vorlage
		</Button>
	{/snippet}
</PageHeader>

<div class="grid">
	<div class="list">
		{#if app.anchors.length === 0}
			<Card>
				<p class="empty">
					Noch keine Anchors registriert. Schalte mindestens 3 Anchors ein und prüfe die
					WLAN-Verbindung.
				</p>
			</Card>
		{/if}

		{#each app.anchors as anchor (anchor.id)}
			{@const draft = drafts.get(anchor.id) ?? anchor.position}
			{@const isDup = duplicates.has(anchor.id)}
			{@const isSaving = savingIds.has(anchor.id)}
			<Card>
				<div class="card-head">
					<div class="row-left">
						<StatusDot status={anchor.status} />
						<DeviceColorDot color={anchor.color} />
						<span class="name">{anchor.name}</span>
					</div>
					<span class="id mono">{anchor.id}</span>
				</div>
				<div class="card-body">
					<PositionInput value={draft} onchange={(v) => updateDraft(anchor.id, v)} />
					{#if isDup}
						<p class="warn">Andere Anchor hat dieselbe Position — Trilateration scheitert.</p>
					{/if}
				</div>
				<div class="card-foot">
					<Button size="sm" loading={isSaving} onclick={() => saveAnchor(anchor.id)}>
						<Save size={14} /> Speichern
					</Button>
				</div>
			</Card>
		{/each}
	</div>

	<div class="preview">
		<div class="preview-head">
			<span class="lbl">Vorschau</span>
			<ViewToggle bind:mode storageKey="anchors" />
		</div>
		<RoomCanvas anchors={previewAnchors} {mode} minHeight={420} />
	</div>
</div>

<Modal bind:open={templateOpen} title="Vorlage anwenden" size="sm">
	{#snippet footer()}
		<Button variant="ghost" onclick={() => (templateOpen = false)}>Abbrechen</Button>
		<Button onclick={applyTemplate}>Übernehmen</Button>
	{/snippet}
	<div class="tpl">
		<div class="tpl-row">
			<label class="opt">
				<input type="radio" bind:group={templateKind} value="rect" />
				<span>Rechteck (4 Anchors)</span>
			</label>
			<label class="opt">
				<input type="radio" bind:group={templateKind} value="tri" />
				<span>Dreieck (3 Anchors)</span>
			</label>
		</div>
		<div class="tpl-grid">
			<Input label="Breite (m)" type="number" step="0.1" bind:value={roomW} />
			<Input label="Tiefe (m)" type="number" step="0.1" bind:value={roomD} />
			<Input label="Höhe (m)" type="number" step="0.1" bind:value={roomH} />
		</div>
		<p class="hint">
			Die ersten {templateKind === 'rect' ? 4 : 3} Anchors aus deiner Liste bekommen die Eckpositionen
			zugewiesen. Speichern musst du jeden einzeln.
		</p>
	</div>
</Modal>

<style>
	.grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-6);
	}
	@media (min-width: 1024px) {
		.grid {
			grid-template-columns: 1fr 1.2fr;
			align-items: start;
		}
		.preview {
			position: sticky;
			top: 80px;
		}
	}
	.list {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}
	.card-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-2);
	}
	.row-left {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.name {
		font-weight: 500;
		color: var(--text-primary);
	}
	.id {
		font-size: var(--text-xs);
		color: var(--text-muted);
	}
	.card-body {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}
	.card-foot {
		display: flex;
		justify-content: flex-end;
	}
	.warn {
		margin: 0;
		color: var(--status-delayed);
		font-size: var(--text-xs);
	}
	.empty {
		margin: 0;
		color: var(--text-secondary);
		font-size: var(--text-sm);
	}
	.preview {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.preview-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: var(--space-2);
	}
	.lbl {
		font-size: var(--text-xs);
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--text-muted);
		font-weight: 500;
	}
	.tpl {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}
	.tpl-row {
		display: flex;
		gap: var(--space-4);
	}
	.opt {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
		font-size: var(--text-sm);
		cursor: pointer;
	}
	.tpl-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-3);
	}
	.hint {
		margin: 0;
		font-size: var(--text-xs);
		color: var(--text-muted);
	}
</style>
