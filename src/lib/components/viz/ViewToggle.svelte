<script>
	import Tabs from '../ui/Tabs.svelte';
	import { onMount } from 'svelte';

	// ---- props ----
	let { mode = $bindable('xy'), storageKey, allow3d = false, onchange } = $props();

	// ---- options ----
	let tabs = $derived([
		{ id: 'xy', label: 'Draufsicht (XY)' },
		{ id: 'xz', label: 'Front (XZ)' },
		{ id: 'yz', label: 'Seite (YZ)' },
		...(allow3d ? [{ id: '3d', label: '3D' }] : [])
	]);

	// ---- mount: hydrate ----
	onMount(() => {
		if (!storageKey) return;
		try {
			const saved = localStorage.getItem(`uwbp.viz.${storageKey}`);
			if (saved && ['xy', 'xz', 'yz', '3d'].includes(saved)) {
				mode = saved;
			}
		} catch {
			// ignore
		}
	});

	function handleChange(id) {
		mode = id;
		try {
			if (storageKey) localStorage.setItem(`uwbp.viz.${storageKey}`, id);
		} catch {
			// ignore
		}
		onchange?.(id);
	}
</script>

<Tabs {tabs} active={mode} onchange={handleChange} />
