<script>
	import { fly } from 'svelte/transition';

	// ---- props ----
	let { title, description, children } = $props();
</script>

<section class="step" in:fly={{ y: 8, duration: 200 }}>
	<header>
		<h2>{title}</h2>
		{#if description}
			<p>{description}</p>
		{/if}
	</header>
	<div class="body">
		{@render children()}
	</div>
</section>

<style>
	.step {
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
	}
	header {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}
	h2 {
		margin: 0;
		font-size: var(--text-2xl);
		font-weight: 600;
		color: var(--text-primary);
	}
	p {
		margin: 0;
		color: var(--text-secondary);
		line-height: 1.6;
	}
	.body {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}
</style>
