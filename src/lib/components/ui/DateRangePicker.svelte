<script>
	import { onMount, onDestroy } from 'svelte';
	import flatpickr from 'flatpickr';
	import { German } from 'flatpickr/dist/l10n/de.js';
	import 'flatpickr/dist/flatpickr.min.css';

	// ---- props ----
	let { from = $bindable(null), to = $bindable(null), label, onchange } = $props();

	// ---- state ----
	let inputEl;
	let fp;

	onMount(() => {
		fp = flatpickr(inputEl, {
			mode: 'range',
			enableTime: true,
			time_24hr: true,
			locale: German,
			dateFormat: 'Y-m-d H:i',
			defaultDate: from && to ? [new Date(from), new Date(to)] : undefined,
			onChange: (dates) => {
				if (dates.length === 2) {
					from = dates[0].getTime();
					to = dates[1].getTime();
					onchange?.({ from, to });
				}
			}
		});
	});

	onDestroy(() => {
		fp?.destroy();
	});
</script>

<label class="field">
	{#if label}<span class="lbl">{label}</span>{/if}
	<input
		bind:this={inputEl}
		class="input mono"
		type="text"
		placeholder="Zeitraum auswählen"
		readonly
	/>
</label>

<style>
	.field {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}
	.lbl {
		font-size: var(--text-xs);
		color: var(--text-secondary);
		font-weight: 500;
	}
	.input {
		padding: var(--space-2) var(--space-3);
		background: var(--bg-tertiary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		color: var(--text-primary);
		font-size: var(--text-sm);
		font-family: var(--font-mono);
		cursor: pointer;
	}
	.input:hover {
		border-color: var(--border-strong);
	}
	.input:focus {
		outline: none;
		border-color: var(--accent);
	}
	:global(.flatpickr-calendar) {
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		color: var(--text-primary);
		box-shadow: var(--shadow-md);
	}
	:global(.flatpickr-day) {
		color: var(--text-primary);
	}
	:global(.flatpickr-day.selected),
	:global(.flatpickr-day.startRange),
	:global(.flatpickr-day.endRange) {
		background: var(--accent);
		border-color: var(--accent);
		color: #fff;
	}
	:global(.flatpickr-day.inRange) {
		background: var(--accent-glow);
		border-color: var(--accent-glow);
		box-shadow:
			-5px 0 0 var(--accent-glow),
			5px 0 0 var(--accent-glow);
	}
	:global(.flatpickr-months .flatpickr-month),
	:global(.flatpickr-current-month input.cur-year),
	:global(.flatpickr-current-month .flatpickr-monthDropdown-months),
	:global(.flatpickr-weekdays),
	:global(.flatpickr-weekday) {
		background: var(--bg-secondary);
		color: var(--text-primary);
	}
	:global(.flatpickr-prev-month),
	:global(.flatpickr-next-month) {
		color: var(--text-primary);
		fill: var(--text-primary);
	}
</style>
