<script>
	import Modal from './Modal.svelte';
	import Button from './Button.svelte';

	// ---- props ----
	let {
		open = $bindable(false),
		title = 'Bestätigen',
		message,
		confirmLabel = 'Bestätigen',
		cancelLabel = 'Abbrechen',
		variant = 'primary',
		onConfirm,
		onCancel
	} = $props();

	function confirm() {
		open = false;
		onConfirm?.();
	}
	function cancel() {
		open = false;
		onCancel?.();
	}
</script>

<Modal bind:open {title} size="sm" onclose={cancel}>
	{#snippet footer()}
		<Button variant="ghost" onclick={cancel}>{cancelLabel}</Button>
		<Button {variant} onclick={confirm}>{confirmLabel}</Button>
	{/snippet}
	<p class="msg">{message}</p>
</Modal>

<style>
	.msg {
		margin: 0;
		color: var(--text-secondary);
		line-height: 1.5;
	}
</style>
