<script>
	import { onMount } from 'svelte';
	import { Canvas, T } from '@threlte/core';
	import { OrbitControls } from '@threlte/extras';
	import Trail3D from './Trail3D.svelte';

	// ---- props ----
	let {
		anchors = [],
		tags = [],
		positions = [],
		tagHistory = null,
		cursorTs = null,
		trails = [],
		minHeight = 460
	} = $props();

	// ---- theme (read once, observe via mutation, but stays referentially stable for helpers) ----
	let mutedColor = $state('#5C6877');
	let borderColor = $state('#2A3444');
	let bgColor = $state('#131922');

	function readTheme() {
		const cs = getComputedStyle(document.documentElement);
		mutedColor = cs.getPropertyValue('--text-muted').trim() || '#5C6877';
		borderColor = cs.getPropertyValue('--border').trim() || '#2A3444';
		bgColor = cs.getPropertyValue('--bg-secondary').trim() || '#131922';
	}

	onMount(() => {
		readTheme();
		const obs = new MutationObserver(readTheme);
		obs.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
		return () => obs.disconnect();
	});

	// ---- helpers (stable references) ----
	const gridArgs = $derived([20, 20, mutedColor, borderColor]);
	const axesArgs = [2];

	// ---- tag position lookup ----
	function tagWorldPosition(tag) {
		if (cursorTs !== null && tagHistory) {
			const entries = tagHistory.get?.(tag.id) ?? tagHistory[tag.id];
			if (entries && entries.length) {
				let cursor = null;
				for (const e of entries) {
					if (e.timestamp <= cursorTs) cursor = e;
					else break;
				}
				if (cursor) return cursor.position;
			}
		}
		const live = positions.find((p) => p.tagId === tag.id);
		if (live) return live.position;
		return tag.position;
	}

	function residualOf(tag) {
		const live = positions.find((p) => p.tagId === tag.id);
		return live?.residual ?? 0;
	}

	// ---- camera defaults: computed ONCE on mount, frozen ever after (so OrbitControls owns the view) ----
	let initialCamPos = $state([8, 5, 8]);
	let initialTarget = $state([2.5, 1, -2]);

	onMount(() => {
		// derive initial camera from anchors only (stable, no live-tag interference)
		const list = anchors.length ? anchors.map((a) => a.position) : [{ x: 2.5, y: 2, z: 1 }];
		const cx = list.reduce((s, p) => s + p.x, 0) / list.length;
		const cy = list.reduce((s, p) => s + p.y, 0) / list.length;
		const cz = list.reduce((s, p) => s + p.z, 0) / list.length;
		let radius = 0;
		for (const p of list) {
			const dx = p.x - cx;
			const dy = p.y - cy;
			const dz = p.z - cz;
			const d = Math.sqrt(dx * dx + dy * dy + dz * dz);
			if (d > radius) radius = d;
		}
		radius = Math.max(4, radius * 1.8);
		initialCamPos = [cx + radius, cz + radius * 0.6, -cy + radius];
		initialTarget = [cx, cz, -cy];
	});
</script>

<div class="wrap" style:height="{minHeight}px" style:--bg={bgColor} style:--border-c={borderColor}>
	<Canvas>
		<T.PerspectiveCamera makeDefault position={initialCamPos} fov={50}>
			<OrbitControls enableDamping target={initialTarget} maxPolarAngle={Math.PI / 2.05} />
		</T.PerspectiveCamera>

		<T.AmbientLight intensity={0.7} />
		<T.DirectionalLight position={[10, 12, 8]} intensity={0.9} />
		<T.HemisphereLight intensity={0.4} groundColor={borderColor} />

		<T.GridHelper args={gridArgs} />
		<T.AxesHelper args={axesArgs} />

		{#each trails as trail (trail.tagId)}
			<Trail3D points={trail.points} color={trail.color} {cursorTs} />
		{/each}

		{#each anchors as a (a.id)}
			<T.Mesh position={[a.position.x, a.position.z, -a.position.y]}>
				<T.BoxGeometry args={[0.25, 0.25, 0.25]} />
				<T.MeshStandardMaterial color={a.color} metalness={0.3} roughness={0.4} />
			</T.Mesh>
		{/each}

		{#each tags as t (t.id)}
			{@const pos = tagWorldPosition(t)}
			{@const lowQ = residualOf(t) > 0.5}
			<T.Group position={[pos.x, pos.z, -pos.y]}>
				<T.Mesh>
					<T.SphereGeometry args={[0.18, 24, 24]} />
					<T.MeshStandardMaterial
						color={t.color}
						emissive={t.color}
						emissiveIntensity={lowQ ? 0.3 : 0.8}
						metalness={0.1}
						roughness={0.3}
					/>
				</T.Mesh>
				<T.PointLight color={t.color} intensity={1.2} distance={2} />
			</T.Group>
		{/each}
	</Canvas>

	<div class="legend">
		<div class="leg-row"><span class="ax x"></span> X</div>
		<div class="leg-row"><span class="ax y"></span> Y</div>
		<div class="leg-row"><span class="ax z"></span> Z</div>
	</div>

	<div class="dev-list">
		{#each anchors as a (a.id)}
			<div class="dev-row">
				<span class="dot" style:background={a.color}></span>
				<span class="dev-name">{a.name}</span>
				<span class="dev-pos mono">
					{a.position.x.toFixed(1)}, {a.position.y.toFixed(1)}, {a.position.z.toFixed(1)}
				</span>
			</div>
		{/each}
		{#each tags as t (t.id)}
			{@const pos = tagWorldPosition(t)}
			<div class="dev-row">
				<span class="dot glow" style:background={t.color}></span>
				<span class="dev-name">{t.name}</span>
				<span class="dev-pos mono">
					{pos.x.toFixed(1)}, {pos.y.toFixed(1)}, {pos.z.toFixed(1)}
				</span>
			</div>
		{/each}
	</div>
</div>

<style>
	.wrap {
		position: relative;
		width: 100%;
		height: 100%;
		background: var(--bg);
		border: 1px solid var(--border-c);
		border-radius: var(--radius-lg);
		overflow: hidden;
	}
	.legend {
		position: absolute;
		top: var(--space-3);
		right: var(--space-3);
		display: flex;
		flex-direction: column;
		gap: 4px;
		padding: var(--space-2) var(--space-3);
		background: color-mix(in srgb, var(--bg-secondary) 85%, transparent);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		font-size: 11px;
		font-family: var(--font-mono);
		color: var(--text-secondary);
		pointer-events: none;
	}
	.leg-row {
		display: flex;
		align-items: center;
		gap: 6px;
	}
	.ax {
		display: inline-block;
		width: 12px;
		height: 2px;
	}
	.ax.x {
		background: #ef4444;
	}
	.ax.y {
		background: #34d399;
	}
	.ax.z {
		background: #4f8eff;
	}
	.dev-list {
		position: absolute;
		left: var(--space-3);
		bottom: var(--space-3);
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: var(--space-2) var(--space-3);
		background: color-mix(in srgb, var(--bg-secondary) 85%, transparent);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		font-size: 11px;
		max-width: 280px;
		pointer-events: none;
	}
	.dev-row {
		display: grid;
		grid-template-columns: 10px 1fr auto;
		gap: 8px;
		align-items: center;
	}
	.dev-name {
		color: var(--text-primary);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.dev-pos {
		color: var(--text-muted);
		font-size: 10px;
	}
	.dot {
		width: 10px;
		height: 10px;
		border-radius: 50%;
	}
	.dot.glow {
		box-shadow: 0 0 6px currentColor;
	}
</style>
