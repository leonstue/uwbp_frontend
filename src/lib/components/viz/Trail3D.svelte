<script>
	import { onDestroy } from 'svelte';
	import { T } from '@threlte/core';
	import {
		BufferGeometry,
		Float32BufferAttribute,
		Color,
		LineBasicMaterial,
		Line,
		AdditiveBlending
	} from 'three';

	// ---- props ----
	let { points = [], color = '#4F8EFF', cursorTs = null } = $props();

	// ---- state ----
	const geometry = new BufferGeometry();
	const material = new LineBasicMaterial({
		vertexColors: true,
		transparent: true,
		blending: AdditiveBlending,
		depthWrite: false
	});
	const line = new Line(geometry, material);
	const baseColor = new Color();

	function rebuild() {
		const visible = cursorTs !== null ? points.filter((p) => p.timestamp <= cursorTs) : points;
		const n = visible.length;
		if (n < 2) {
			geometry.setAttribute('position', new Float32BufferAttribute([], 3));
			geometry.setAttribute('color', new Float32BufferAttribute([], 3));
			geometry.setDrawRange(0, 0);
			return;
		}
		baseColor.set(color);
		const ref = cursorTs !== null ? cursorTs : Date.now();
		const oldest = visible[0]?.timestamp ?? ref;
		const span = Math.max(500, ref - oldest);

		const positions = new Float32Array(n * 3);
		const colors = new Float32Array(n * 3);
		for (let i = 0; i < n; i++) {
			const p = visible[i];
			positions[i * 3 + 0] = p.position.x;
			positions[i * 3 + 1] = p.position.z;
			positions[i * 3 + 2] = -p.position.y;

			const age = ref - p.timestamp;
			let t = 1 - age / span;
			if (i > 0) {
				const prev = visible[i - 1];
				const dx = p.position.x - prev.position.x;
				const dy = p.position.y - prev.position.y;
				const dz = p.position.z - prev.position.z;
				const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
				const dt = Math.max(0.016, (p.timestamp - prev.timestamp) / 1000);
				const speed = dist / dt;
				const speedFactor = Math.max(0.5, Math.min(1.4, 1 - speed * 0.5));
				t *= speedFactor;
			}
			t = Math.max(0.05, Math.min(1, t));
			colors[i * 3 + 0] = baseColor.r * t;
			colors[i * 3 + 1] = baseColor.g * t;
			colors[i * 3 + 2] = baseColor.b * t;
		}
		geometry.setAttribute('position', new Float32BufferAttribute(positions, 3));
		geometry.setAttribute('color', new Float32BufferAttribute(colors, 3));
		geometry.setDrawRange(0, n);
		geometry.attributes.position.needsUpdate = true;
		geometry.attributes.color.needsUpdate = true;
	}

	$effect(() => {
		void points;
		void color;
		void cursorTs;
		rebuild();
	});

	onDestroy(() => {
		geometry.dispose();
		material.dispose();
	});
</script>

<T is={line} />
