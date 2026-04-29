<script>
	import Button from '../ui/Button.svelte';
	import Select from '../ui/Select.svelte';
	import Play from 'lucide-svelte/icons/play';
	import Pause from 'lucide-svelte/icons/pause';
	import Square from 'lucide-svelte/icons/square';

	// ---- props ----
	let {
		playing = $bindable(false),
		speed = $bindable(1),
		onPlay,
		onPause,
		onStop
	} = $props();

	const speedOptions = [
		{ value: 1, label: '1×' },
		{ value: 2, label: '2×' },
		{ value: 5, label: '5×' },
		{ value: 10, label: '10×' }
	];

	function play() {
		playing = true;
		onPlay?.();
	}
	function pause() {
		playing = false;
		onPause?.();
	}
	function stop() {
		playing = false;
		onStop?.();
	}
</script>

<div class="ctrl">
	{#if playing}
		<Button variant="secondary" size="sm" onclick={pause}>
			<Pause size={14} /> Pause
		</Button>
	{:else}
		<Button size="sm" onclick={play}>
			<Play size={14} /> Play
		</Button>
	{/if}
	<Button variant="ghost" size="sm" onclick={stop}>
		<Square size={14} /> Stop
	</Button>
	<Select bind:value={speed} options={speedOptions} />
</div>

<style>
	.ctrl {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}
</style>
