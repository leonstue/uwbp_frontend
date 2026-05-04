<script>
	import ProgressBar from './ProgressBar.svelte';
	import Button from '../ui/Button.svelte';
	import ConfirmDialog from '../ui/ConfirmDialog.svelte';
	import ChevronLeft from 'lucide-svelte/icons/chevron-left';
	import ChevronRight from 'lucide-svelte/icons/chevron-right';
	import X from 'lucide-svelte/icons/x';

	// ---- props ----
	let {
		steps = [],
		current = $bindable(0),
		canGoNext = true,
		nextLabel = 'Weiter',
		showBack = true,
		showNext = true,
		onCancel,
		onNext,
		children
	} = $props();

	// ---- state ----
	let cancelOpen = $state(false);

	// ---- actions ----
	function back() {
		if (current > 0) current -= 1;
	}
	function next() {
		if (!canGoNext) return;
		if (onNext) onNext();
		else if (current < steps.length - 1) current += 1;
	}
</script>

<div class="shell">
	<div class="topline">
		<ProgressBar {steps} {current} />
		<button class="cancel" type="button" aria-label="Abbrechen" onclick={() => (cancelOpen = true)}>
			<X size={18} />
		</button>
	</div>

	<div class="content">
		{@render children()}
	</div>

	<footer class="foot">
		{#if showBack}
			<Button variant="ghost" onclick={back} disabled={current === 0}>
				<ChevronLeft size={14} /> Zurück
			</Button>
		{:else}
			<span></span>
		{/if}
		{#if showNext}
			<Button onclick={next} disabled={!canGoNext}>
				{nextLabel}
				<ChevronRight size={14} />
			</Button>
		{/if}
	</footer>
</div>

<ConfirmDialog
	bind:open={cancelOpen}
	title="Starten abbrechen?"
	message="Du kannst den Wizard jederzeit aus den Einstellungen erneut starten."
	confirmLabel="Abbrechen"
	cancelLabel="Weiter konfigurieren"
	variant="danger"
	onConfirm={onCancel}
/>

<style>
	.shell {
		max-width: 800px;
		margin: 0 auto;
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
		padding: var(--space-6) var(--space-4);
	}
	.topline {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}
	.cancel {
		flex-shrink: 0;
		width: 32px;
		height: 32px;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--bg-secondary);
		color: var(--text-muted);
	}
	.cancel:hover {
		color: var(--text-primary);
	}
	.content {
		min-height: 360px;
	}
	.foot {
		display: flex;
		justify-content: space-between;
		gap: var(--space-3);
		padding-top: var(--space-4);
		border-top: 1px solid var(--border);
	}
</style>
