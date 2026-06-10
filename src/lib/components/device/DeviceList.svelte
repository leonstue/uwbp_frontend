<script>
	import DeviceRow from './DeviceRow.svelte';
	import DeviceCard from './DeviceCard.svelte';

	// ---- props ----
	let { devices = [], onSave, onRemove, savingIds = new Set() } = $props();
</script>

<div class="list-desktop">
	<table>
		<colgroup>
			<col style="width: 32px" />
			<col style="width: 160px" />
			<col style="width: 84px" />
			<col style="width: auto" />
			<col style="width: 110px" />
			<col style="width: 140px" />
			<col style="width: 180px" />
			<col style="width: 56px" />
		</colgroup>
		<thead>
			<tr>
				<th></th>
				<th>ID</th>
				<th>Typ</th>
				<th>Name</th>
				<th>Farbe</th>
				<th>Letzter Kontakt</th>
				<th>Position</th>
				<th></th>
			</tr>
		</thead>
		<tbody>
			{#each devices as device (device.id)}
				<DeviceRow
					{device}
					saving={savingIds.has(device.id)}
					onSave={(data) => onSave?.(device.id, data)}
					onRemove={() => onRemove?.(device.id)}
				/>
			{/each}
		</tbody>
	</table>
</div>

<div class="list-mobile">
	{#each devices as device (device.id)}
		<DeviceCard {device} />
	{/each}
</div>

<style>
	.list-desktop {
		display: none;
		overflow-x: auto;
		border: 1px solid var(--border);
		border-radius: var(--radius-lg);
		background: var(--bg-secondary);
	}
	table {
		width: 100%;
		border-collapse: collapse;
		table-layout: fixed;
	}
	td,
	th {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	thead {
		background: var(--bg-tertiary);
	}
	th {
		padding: var(--space-3);
		text-align: left;
		font-size: var(--text-xs);
		font-weight: 500;
		color: var(--text-muted);
		text-transform: uppercase;
		letter-spacing: 0.04em;
		border-bottom: 1px solid var(--border);
	}
	.list-mobile {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	@media (min-width: 768px) {
		.list-desktop {
			display: block;
		}
		.list-mobile {
			display: none;
		}
	}
</style>
