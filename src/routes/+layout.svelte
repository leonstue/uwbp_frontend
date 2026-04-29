<script>
	import '../app.css';
	import { page } from '$app/state';
	import ApiClient from '$lib/components/util/ApiClient.svelte';
	import AppState from '$lib/components/util/AppState.svelte';
	import AppShell from '$lib/components/layout/AppShell.svelte';
	import ToastHost from '$lib/components/ui/ToastHost.svelte';

	// ---- props ----
	let { children } = $props();

	// ---- derived ----
	let isWizard = $derived(page.url.pathname.startsWith('/setup'));
</script>

<ApiClient>
	<AppState>
		<ToastHost>
			<AppShell compact={isWizard}>
				{@render children()}
			</AppShell>
		</ToastHost>
	</AppState>
</ApiClient>
