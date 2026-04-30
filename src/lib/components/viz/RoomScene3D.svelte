<script>
	import { onMount } from 'svelte';
	import { Canvas, T } from '@threlte/core';
	import { OrbitControls } from '@threlte/extras';

	// ---- props ----
	let {
		anchors = [],
		tags = [],
		positions = [],
		tagHistory = null,
		cursorTs = null,
		minHeight = 460
	} = $props();

	// ---- state ----
	let bgColor = $state('#131922');
	let mutedColor = $state('#5C6877');
	let borderColor = $state('#2A3444');

	function readTheme() {
		const cs = getComputedStyle(document.documentElement);
		bgColor = cs.getPropertyValue('--bg-secondary').trim() || '#131922';
		mutedColor = cs.getPropertyValue('--text-muted').trim() || '#5C6877';
		borderColor = cs.getPropertyValue('--border').trim() || '#2A3444';
	}

	onMount(() => {
		readTheme();
		const obs = new MutationObserver(readTheme);
		obs.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
		return () => obs.disconnect();
	});

	// ---- helpers ----
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
		if (cursorTs !== null && tagHistory) {
			const entries = tagHistory.get?.(tag.id) ?? tagHistory[tag.id];
			if (entries) {
				let cursor = null;
				for (const e of entries) {
					if (e.timestamp <= cursorTs) cursor = e;
					else break;
				}
				if (cursor) return cursor.residual ?? 0;
			}
		}
		const live = positions.find((p) => p.tagId === tag.id);
		return live?.residual ?? 0;
	}

	// ---- derived: scene bounds for camera ----
	let sceneCenter = $derived.by(() => {
		const all = [...anchors.map((a) => a.position), ...tags.map((t) => tagWorldPosition(t))];
		if (!all.length) return { x: 2.5, y: 2, z: 1 };
		const sum = all.reduce((acc, p) => ({ x: acc.x + p.x, y: acc.y + p.y, z: acc.z + p.z }), {
			x: 0,
			y: 0,
			z: 0
		});
		return { x: sum.x / all.length, y: sum.y / all.length, z: sum.z / all.length };
	});

	let sceneRadius = $derived.by(() => {
		const all = [...anchors.map((a) => a.position), ...tags.map((t) => tagWorldPosition(t))];
		if (!all.length) return 6;
		let max = 0;
		for (const p of all) {
			const dx = p.x - sceneCenter.x;
			const dy = p.y - sceneCenter.y;
			const dz = p.z - sceneCenter.z;
			const d = Math.sqrt(dx * dx + dy * dy + dz * dz);
			if (d > max) max = d;
		}
		return Math.max(4, max * 1.8);
	});

	// camera helper: world (x, y, z) → three (x, z, -y)
	let camPos = $derived([
		sceneCenter.x + sceneRadius,
		sceneCenter.z + sceneRadius * 0.6,
		-sceneCenter.y + sceneRadius
	]);
	let camTarget = $derived([sceneCenter.x, sceneCenter.z, -sceneCenter.y]);
</script>

<div class="wrap" style:height="{minHeight}px" style:--bg={bgColor} style:--border-c={borderColor}>
	<Canvas>
		<T.PerspectiveCamera makeDefault position={camPos} fov={50}>
			<OrbitControls enableDamping target={camTarget} maxPolarAngle={Math.PI / 2.05} />
		</T.PerspectiveCamera>

		<T.AmbientLight intensity={0.7} />
		<T.DirectionalLight position={[10, 12, 8]} intensity={0.9} />
		<T.HemisphereLight intensity={0.4} groundColor={borderColor} />

		<!-- ground grid: native three.js GridHelper -->
		<T.GridHelper args={[20, 20, mutedColor, borderColor]} />

		<!-- axes helper at world origin (red=X, green=Y_three=Z_world, blue=Z_three=−Y_world) -->
		<T.AxesHelper args={[2]} />

		<!-- anchors as cubes; world (x,y,z) → three (x, z, -y) -->
		{#each anchors as a (a.id)}
			<T.Mesh position={[a.position.x, a.position.z, -a.position.y]}>
				<T.BoxGeometry args={[0.25, 0.25, 0.25]} />
				<T.MeshStandardMaterial color={a.color} metalness={0.3} roughness={0.4} />
			</T.Mesh>
		{/each}

		<!-- tags as glowing spheres -->
		{#each tags as t (t.id)}
			{@const pos = tagWorldPosition(t)}
			{@const lowQ = residualOf(t) > 0.5}
			<T.Group position={[pos.x, pos.z, -pos.y]}>
				<T.Mesh>
					<T.SphereGeometry args={[0.18, 32, 32]} />
					<T.MeshStandardMaterial
						color={t.color}
						emissive={t.color}
						emissiveIntensity={lowQ ? 0.3 : 0.8}
						metalness={0.1}
						roughness={0.3}
					/>
				</T.Mesh>
				<T.PointLight color={t.color} intensity={1.5} distance={2.5} />
			</T.Group>
		{/each}
	</Canvas>

	<!-- DOM overlay legend (axes legend + device names) -->
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
