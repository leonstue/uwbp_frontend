<script>
	import { fly } from 'svelte/transition';
	import CheckCircle from 'lucide-svelte/icons/check-circle-2';
	import AlertTriangle from 'lucide-svelte/icons/alert-triangle';
	import XCircle from 'lucide-svelte/icons/x-circle';
	import Info from 'lucide-svelte/icons/info';

	// ---- props ----
	let { type = 'info', message, onclose } = $props();
</script>

<div
	class="toast"
	class:success={type === 'success'}
	class:warn={type === 'warn'}
	class:error={type === 'error'}
	class:info={type === 'info'}
	role="status"
	transition:fly={{ y: 12, duration: 200 }}
>
	<span class="icon">
		{#if type === 'success'}
			<CheckCircle size={16} />
		{:else if type === 'warn'}
			<AlertTriangle size={16} />
		{:else if type === 'error'}
			<XCircle size={16} />
		{:else}
			<Info size={16} />
		{/if}
	</span>
	<span class="msg">{message}</span>
	<button class="close" type="button" aria-label="Schließen" onclick={onclose}>×</button>
</div>

<style>
	.toast {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3) var(--space-4);
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		box-shadow: var(--shadow-md);
		font-size: var(--text-sm);
		min-width: 260px;
	}
	.icon {
		display: inline-flex;
	}
	.msg {
		flex: 1;
		color: var(--text-primary);
	}
	.close {
		color: var(--text-muted);
		font-size: 18px;
		line-height: 1;
		padding: 0 var(--space-1);
	}
	.close:hover {
		color: var(--text-primary);
	}
	.success {
		border-color: color-mix(in srgb, var(--status-online) 50%, transparent);
		color: var(--status-online);
	}
	.warn {
		border-color: color-mix(in srgb, var(--status-delayed) 50%, transparent);
		color: var(--status-delayed);
	}
	.error {
		border-color: color-mix(in srgb, var(--status-offline) 50%, transparent);
		color: var(--status-offline);
	}
	.info {
		border-color: color-mix(in srgb, var(--accent) 50%, transparent);
		color: var(--accent);
	}
</style>
