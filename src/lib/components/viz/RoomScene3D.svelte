<script>
	import { onMount } from 'svelte';
	import { Canvas, T } from '@threlte/core';
	import { OrbitControls, Grid, HTML } from '@threlte/extras';

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
</script>

<div
	class="wrap"
	style:min-height="{minHeight}px"
	style:--bg={bgColor}
	style:--border-c={borderColor}
>
	<Canvas>
		<T.PerspectiveCamera
			makeDefault
			position={[
				sceneCenter.x + sceneRadius,
				sceneCenter.z + sceneRadius * 0.6,
				sceneCenter.y + sceneRadius
			]}
			fov={50}
		>
			<OrbitControls
				enableDamping
				target={[sceneCenter.x, sceneCenter.z, sceneCenter.y]}
				maxPolarAngle={Math.PI / 2.05}
			/>
		</T.PerspectiveCamera>

		<T.AmbientLight intensity={0.6} />
		<T.DirectionalLight position={[10, 12, 8]} intensity={0.8} />
		<T.HemisphereLight intensity={0.3} groundColor={borderColor} />

		<!-- ground grid (X/Y plane at Z=0) -->
		<T.Group rotation={[Math.PI / 2, 0, 0]}>
			<Grid
				cellSize={1}
				cellColor={borderColor}
				sectionSize={5}
				sectionColor={mutedColor}
				infiniteGrid={false}
				gridSize={[20, 20]}
				fadeDistance={30}
			/>
		</T.Group>

		<!-- world axes: X=red, Y=green, Z=blue (length 1.5m at origin) -->
		<T.Group>
			<!-- X axis (red) -->
			<T.Mesh position={[0.75, 0, 0]} rotation={[0, 0, -Math.PI / 2]}>
				<T.CylinderGeometry args={[0.015, 0.015, 1.5, 8]} />
				<T.MeshStandardMaterial color="#EF4444" />
			</T.Mesh>
			<T.Mesh position={[1.55, 0, 0]} rotation={[0, 0, -Math.PI / 2]}>
				<T.ConeGeometry args={[0.05, 0.12, 12]} />
				<T.MeshStandardMaterial color="#EF4444" />
			</T.Mesh>
			<HTML position={[1.75, 0, 0]} center>
				<span class="axis-label" style:color="#EF4444">X</span>
			</HTML>

			<!-- Y axis (green) — three.js Y is up, world Y maps to scene Z -->
			<T.Mesh position={[0, 0, -0.75]}>
				<T.CylinderGeometry args={[0.015, 0.015, 1.5, 8]} />
				<T.MeshStandardMaterial color="#34D399" />
			</T.Mesh>
			<T.Mesh position={[0, 0, -1.55]} rotation={[Math.PI / 2, 0, 0]}>
				<T.ConeGeometry args={[0.05, 0.12, 12]} />
				<T.MeshStandardMaterial color="#34D399" />
			</T.Mesh>
			<HTML position={[0, 0, -1.75]} center>
				<span class="axis-label" style:color="#34D399">Y</span>
			</HTML>

			<!-- Z axis (blue) -->
			<T.Mesh position={[0, 0.75, 0]}>
				<T.CylinderGeometry args={[0.015, 0.015, 1.5, 8]} />
				<T.MeshStandardMaterial color="#4F8EFF" />
			</T.Mesh>
			<T.Mesh position={[0, 1.55, 0]}>
				<T.ConeGeometry args={[0.05, 0.12, 12]} />
				<T.MeshStandardMaterial color="#4F8EFF" />
			</T.Mesh>
			<HTML position={[0, 1.75, 0]} center>
				<span class="axis-label" style:color="#4F8EFF">Z</span>
			</HTML>
		</T.Group>

		<!-- anchors as cubes -->
		{#each anchors as a (a.id)}
			<T.Group position={[a.position.x, a.position.z, -a.position.y]}>
				<T.Mesh>
					<T.BoxGeometry args={[0.25, 0.25, 0.25]} />
					<T.MeshStandardMaterial color={a.color} metalness={0.3} roughness={0.4} />
				</T.Mesh>
				<HTML position={[0, 0.3, 0]} center>
					<span class="label">{a.name}</span>
				</HTML>
			</T.Group>
		{/each}

		<!-- tags as glowing spheres -->
		{#each tags as t (t.id)}
			{@const pos = tagWorldPosition(t)}
			{@const lowQ = residualOf(t) > 0.5}
			<T.Group position={[pos.x, pos.z, -pos.y]}>
				<T.Mesh>
					<T.SphereGeometry args={[0.15, 32, 32]} />
					<T.MeshStandardMaterial
						color={t.color}
						emissive={t.color}
						emissiveIntensity={lowQ ? 0.3 : 0.7}
						metalness={0.1}
						roughness={0.3}
					/>
				</T.Mesh>
				<T.PointLight color={t.color} intensity={1.5} distance={2} />
				<HTML position={[0, 0.28, 0]} center>
					<span class="label tag-label">{t.name}</span>
				</HTML>
			</T.Group>
		{/each}
	</Canvas>
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
	:global(.label) {
		display: inline-block;
		padding: 2px 6px;
		background: color-mix(in srgb, var(--bg-secondary) 85%, transparent);
		border: 1px solid var(--border);
		border-radius: var(--radius-sm);
		color: var(--text-primary);
		font-size: 11px;
		font-weight: 500;
		font-family: var(--font-sans);
		white-space: nowrap;
		pointer-events: none;
		transform: translateY(-50%);
	}
	:global(.tag-label) {
		font-family: var(--font-mono);
	}
	:global(.axis-label) {
		display: inline-block;
		font-family: var(--font-mono);
		font-size: 14px;
		font-weight: 600;
		pointer-events: none;
		text-shadow: 0 0 4px rgba(0, 0, 0, 0.5);
	}
</style>
