<script>
	import StatusDot from '../status/StatusDot.svelte';
	import LastSeen from '../status/LastSeen.svelte';
	import DeviceColorDot from './DeviceColorDot.svelte';
	import Badge from '../ui/Badge.svelte';
	import Button from '../ui/Button.svelte';
	import Trash from 'lucide-svelte/icons/trash-2';

	// ---- props ----
	let { device, onSave, onRemove, saving = false } = $props();

	// ---- state ----
	let nameDraft = $state(device.name);
	let colorDraft = $state(device.color);
	let saveTimer;

	// ---- effects ----
	$effect(() => {
		nameDraft = device.name;
		colorDraft = device.color;
	});

	// ---- actions ----
	function commit() {
		if (nameDraft === device.name && colorDraft === device.color) return;
		onSave?.({ name: nameDraft, color: colorDraft });
	}

	function debouncedCommit() {
		clearTimeout(saveTimer);
		saveTimer = setTimeout(commit, 500);
	}

	// ---- derived ----
	let posLabel = $derived(
		device?.position
			? `${device.position.x.toFixed(2)}, ${device.position.y.toFixed(2)}, ${device.position.z.toFixed(2)}`
			: '–'
	);
</script>

<tr class="row" class:saving>
	<td>
		<StatusDot status={device.status} size={8} />
	</td>
	<td class="mono id">{device.id}</td>
	<td>
		<Badge tone={device.type === 'anchor' ? 'accent' : 'neutral'} size="sm">
			{device.type === 'anchor' ? 'Anchor' : 'Tag'}
		</Badge>
	</td>
	<td>
		<input
			class="inline-input"
			type="text"
			bind:value={nameDraft}
			onblur={commit}
			oninput={debouncedCommit}
			aria-label="Name"
		/>
	</td>
	<td>
		<span class="color-cell">
			<DeviceColorDot color={colorDraft} />
			<input
				class="color-input"
				type="color"
				bind:value={colorDraft}
				onchange={commit}
				aria-label="Farbe"
			/>
		</span>
	</td>
	<td><LastSeen timestamp={device.lastSeen} /></td>
	<td class="mono pos">{posLabel}</td>
	<td>
		<Button variant="ghost" size="sm" onclick={() => onRemove?.()} aria-label="Vergessen">
			<Trash size={14} />
		</Button>
	</td>
</tr>

<style>
	.row {
		border-bottom: 1px solid var(--border);
		transition: background-color 150ms ease;
	}
	.row:hover {
		background: var(--bg-tertiary);
	}
	.row.saving {
		opacity: 0.6;
	}
	td {
		padding: var(--space-3);
		font-size: var(--text-sm);
		vertical-align: middle;
	}
	.mono {
		font-family: var(--font-mono);
		font-variant-numeric: tabular-nums;
	}
	.id {
		font-size: var(--text-xs);
		color: var(--text-secondary);
	}
	.pos {
		font-size: var(--text-xs);
		color: var(--text-secondary);
	}
	.inline-input {
		width: 100%;
		min-width: 120px;
		padding: 4px var(--space-2);
		background: transparent;
		border: 1px solid transparent;
		border-radius: var(--radius-sm);
		color: var(--text-primary);
		font-size: var(--text-sm);
	}
	.inline-input:hover {
		border-color: var(--border);
	}
	.inline-input:focus {
		outline: none;
		border-color: var(--accent);
		background: var(--bg-tertiary);
	}
	.color-cell {
		display: inline-flex;
		align-items: center;
		gap: var(--space-2);
	}
	.color-input {
		width: 28px;
		height: 24px;
		padding: 1px;
		border: 1px solid var(--border);
		border-radius: var(--radius-sm);
		background: var(--bg-tertiary);
		cursor: pointer;
	}
</style>
