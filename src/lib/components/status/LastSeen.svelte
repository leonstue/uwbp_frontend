<script>
	import dayjs from 'dayjs';
	import relativeTime from 'dayjs/plugin/relativeTime';
	import 'dayjs/locale/de';

	dayjs.extend(relativeTime);
	dayjs.locale('de');

	// ---- props ----
	let { timestamp, prefix = '' } = $props();

	// ---- state ----
	let now = $state(Date.now());

	// ---- effects ----
	$effect(() => {
		const id = setInterval(() => (now = Date.now()), 1000);
		return () => clearInterval(id);
	});

	// ---- derived ----
	let label = $derived(timestamp ? dayjs(timestamp).from(now) : '–');
</script>

<span class="last-seen mono">{prefix}{label}</span>

<style>
	.last-seen {
		color: var(--text-muted);
		font-size: var(--text-xs);
	}
</style>
