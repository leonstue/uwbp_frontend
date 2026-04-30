<script>
	import { getContext } from 'svelte';
	import { goto } from '$app/navigation';
	import WizardShell from '$lib/components/wizard/WizardShell.svelte';
	import WizardStep from '$lib/components/wizard/WizardStep.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Input from '$lib/components/ui/Input.svelte';
	import StatusDot from '$lib/components/status/StatusDot.svelte';
	import DeviceColorDot from '$lib/components/device/DeviceColorDot.svelte';
	import ColorPicker from '$lib/components/ui/ColorPicker.svelte';
	import PositionInput from '$lib/components/device/PositionInput.svelte';
	import RoomCanvas from '$lib/components/viz/RoomCanvas.svelte';
	import Radio from 'lucide-svelte/icons/radio';
	import CheckCircle from 'lucide-svelte/icons/check-circle-2';

	// ---- context ----
	const app = getContext('app');
	const api = getContext('api');
	const toast = getContext('toast');

	// ---- state ----
	let current = $state(0);
	let drafts = $state(new Map());

	// ---- step config ----
	const steps = ['Willkommen', 'Anchors', 'Benennen', 'Positionen', 'Tags', 'Benennen', 'Fertig'];

	// ---- derived ----
	let anchorCount = $derived(app.anchors.length);
	let tagCount = $derived(app.tags.length);

	let canGoNext = $derived.by(() => {
		if (current === 1) return anchorCount >= 3;
		if (current === 4) return tagCount >= 1;
		return true;
	});

	let previewAnchors = $derived(
		app.anchors.map((a) => ({ ...a, position: drafts.get(a.id) ?? a.position }))
	);

	// ---- actions ----
	async function saveName(id, name, color) {
		try {
			await api.devices.update(id, { name, color });
			app.refetchDevices();
		} catch (e) {
			toast.push({ type: 'error', message: 'Speichern fehlgeschlagen: ' + e.message });
		}
	}

	function updateDraft(id, pos) {
		const next = new Map(drafts);
		next.set(id, pos);
		drafts = next;
	}

	async function savePosition(id) {
		const pos = drafts.get(id);
		if (!pos) return;
		try {
			await api.anchors.setPosition(id, pos.x, pos.y, pos.z);
			toast.push({ type: 'success', message: 'Position gespeichert' });
			app.refetchDevices();
		} catch (e) {
			toast.push({ type: 'error', message: 'Fehler: ' + e.message });
		}
	}

	function cancel() {
		goto('/');
	}

	function finish() {
		goto('/');
	}
</script>

<WizardShell
	{steps}
	bind:current
	{canGoNext}
	onCancel={cancel}
	onNext={current === 6 ? finish : undefined}
	nextLabel={current === 6 ? 'Zum Dashboard' : 'Weiter'}
>
	{#if current === 0}
		<WizardStep
			title="Willkommen beim UWBP Setup"
			description="Wir richten dein Indoor-Positioning-System Schritt für Schritt ein. Halte deine Anchors und Tags bereit."
		>
			<Card>
				<ul class="bullets">
					<li><Radio size={16} /> Schalte zuerst alle Anchors ein.</li>
					<li><Radio size={16} /> Danach gibst du jedem Anchor eine Position im Raum.</li>
					<li><Radio size={16} /> Anschließend folgen die Tags.</li>
				</ul>
			</Card>
		</WizardStep>
	{:else if current === 1}
		<WizardStep
			title="Anchors einschalten"
			description="Verbinde mindestens 3 Anchors mit dem Strom. Sie registrieren sich automatisch."
		>
			<Card>
				<div class="counter">
					<span class="big mono">{anchorCount}</span>
					<span class="lbl">Anchors verbunden</span>
				</div>
				{#if anchorCount === 0}
					<p class="hint">Warte auf Anchors …</p>
				{/if}
			</Card>
			<div class="dev-grid">
				{#each app.anchors as a (a.id)}
					<div class="dev-mini">
						<StatusDot status={a.status} />
						<DeviceColorDot color={a.color} />
						<span class="name">{a.name}</span>
						<span class="id mono">{a.id}</span>
					</div>
				{/each}
			</div>
		</WizardStep>
	{:else if current === 2}
		<WizardStep
			title="Anchors benennen"
			description="Gib jedem Anchor einen einprägsamen Namen und eine Farbe."
		>
			{#each app.anchors as a (a.id)}
				<Card>
					<div class="namer">
						<StatusDot status={a.status} />
						<Input
							label="Name"
							value={a.name}
							oninput={(e) => saveName(a.id, e.target.value, a.color)}
						/>
						<ColorPicker
							label="Farbe"
							value={a.color}
							onchange={(e) => saveName(a.id, a.name, e.target.value)}
						/>
					</div>
				</Card>
			{/each}
		</WizardStep>
	{:else if current === 3}
		<WizardStep
			title="Anchor-Positionen"
			description="Trage die Position jedes Anchors im Raum ein. X = Breite, Y = Tiefe, Z = Höhe (Meter)."
		>
			<div class="pos-grid">
				<div class="pos-list">
					{#each app.anchors as a (a.id)}
						{@const draft = drafts.get(a.id) ?? a.position}
						<Card padding="sm">
							<div class="namer">
								<DeviceColorDot color={a.color} />
								<span class="name">{a.name}</span>
							</div>
							<PositionInput value={draft} onchange={(v) => updateDraft(a.id, v)} />
							<div class="row-end">
								<Button size="sm" variant="secondary" onclick={() => savePosition(a.id)}>
									Speichern
								</Button>
							</div>
						</Card>
					{/each}
				</div>
				<div class="preview">
					<RoomCanvas anchors={previewAnchors} mode="xy" minHeight={320} />
				</div>
			</div>
		</WizardStep>
	{:else if current === 4}
		<WizardStep
			title="Tags einschalten"
			description="Schalte deine Tags ein. Sie registrieren sich genauso wie die Anchors."
		>
			<Card>
				<div class="counter">
					<span class="big mono">{tagCount}</span>
					<span class="lbl">Tags verbunden</span>
				</div>
			</Card>
			<div class="dev-grid">
				{#each app.tags as t (t.id)}
					<div class="dev-mini">
						<StatusDot status={t.status} />
						<DeviceColorDot color={t.color} />
						<span class="name">{t.name}</span>
						<span class="id mono">{t.id}</span>
					</div>
				{/each}
			</div>
		</WizardStep>
	{:else if current === 5}
		<WizardStep title="Tags benennen" description="Gib jedem Tag einen Namen und eine Farbe.">
			{#each app.tags as t (t.id)}
				<Card>
					<div class="namer">
						<StatusDot status={t.status} />
						<Input
							label="Name"
							value={t.name}
							oninput={(e) => saveName(t.id, e.target.value, t.color)}
						/>
						<ColorPicker
							label="Farbe"
							value={t.color}
							onchange={(e) => saveName(t.id, t.name, e.target.value)}
						/>
					</div>
				</Card>
			{/each}
		</WizardStep>
	{:else if current === 6}
		<WizardStep
			title="Fertig!"
			description="Dein System ist eingerichtet. Du kannst jetzt zum Dashboard wechseln."
		>
			<Card>
				<div class="done">
					<CheckCircle size={48} />
					<p>{anchorCount} Anchors und {tagCount} Tags konfiguriert.</p>
				</div>
			</Card>
		</WizardStep>
	{/if}
</WizardShell>

<style>
	.bullets {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin: 0;
		padding: 0;
		list-style: none;
		color: var(--text-secondary);
	}
	.bullets li {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.counter {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-4) 0;
	}
	.big {
		font-size: 64px;
		font-weight: 600;
		color: var(--accent);
	}
	.lbl {
		color: var(--text-muted);
		font-size: var(--text-sm);
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}
	.hint {
		text-align: center;
		color: var(--text-muted);
		font-size: var(--text-sm);
		margin: 0;
	}
	.dev-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
		gap: var(--space-3);
	}
	.dev-mini {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3);
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
	}
	.name {
		flex: 1;
		font-weight: 500;
		font-size: var(--text-sm);
		color: var(--text-primary);
	}
	.id {
		font-size: 11px;
		color: var(--text-muted);
	}
	.namer {
		display: grid;
		grid-template-columns: auto 1fr auto;
		gap: var(--space-3);
		align-items: end;
	}
	.pos-grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: var(--space-4);
	}
	@media (min-width: 900px) {
		.pos-grid {
			grid-template-columns: 1fr 1fr;
		}
	}
	.pos-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.row-end {
		display: flex;
		justify-content: flex-end;
	}
	.done {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-3);
		color: var(--status-online);
		text-align: center;
	}
	.done p {
		color: var(--text-secondary);
		margin: 0;
	}
</style>
