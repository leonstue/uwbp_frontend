<script>
	import { onMount } from 'svelte';
	import { drawGrid } from './GridLayer.svelte';
	import { drawAxisLabels } from './AxisLabels.svelte';
	import { drawAnchor } from './AnchorMarker.svelte';
	import { drawTag } from './TagMarker.svelte';
	import { drawTrail } from './TrailLine.svelte';

	// ---- props ----
	let {
		anchors = [],
		tags = [],
		positions = [],
		trails = [],
		mode = 'xy',
		cursorTs = null,
		showTrailFade = false,
		minHeight = 360
	} = $props();

	// ---- state ----
	let canvasEl;
	let wrapEl;
	let width = $state(600);
	let height = $state(400);
	let dpr = $state(1);
	let hover = $state(null);

	// ---- helpers ----
	function project(p, m) {
		if (m === 'xy') return { h: p.x, v: p.y };
		if (m === 'xz') return { h: p.x, v: p.z };
		return { h: p.y, v: p.z };
	}

	function getThemeColors() {
		const cs = getComputedStyle(document.documentElement);
		return {
			bg: cs.getPropertyValue('--bg-secondary').trim() || '#131922',
			grid: cs.getPropertyValue('--border').trim() || '#2A3444',
			gridStrong: cs.getPropertyValue('--border-strong').trim() || '#3D4A5E',
			text: cs.getPropertyValue('--text-primary').trim() || '#E6EDF3',
			muted: cs.getPropertyValue('--text-muted').trim() || '#5C6877',
			warn: cs.getPropertyValue('--status-delayed').trim() || '#FBBF24',
			sans: cs.getPropertyValue('--font-sans').trim() || 'Inter, sans-serif',
			mono: cs.getPropertyValue('--font-mono').trim() || 'JetBrains Mono, monospace'
		};
	}

	function computeTransform() {
		const projected = [
			...anchors.map((a) => project(a.position, mode)),
			...positions.map((p) => project(p.position, mode))
		];
		let minH = -1;
		let maxH = 6;
		let minV = -1;
		let maxV = 5;
		if (projected.length) {
			minH = Math.min(...projected.map((p) => p.h));
			maxH = Math.max(...projected.map((p) => p.h));
			minV = Math.min(...projected.map((p) => p.v));
			maxV = Math.max(...projected.map((p) => p.v));
		}
		const padding = 1;
		minH -= padding;
		maxH += padding;
		minV -= padding;
		maxV += padding;
		const worldW = Math.max(2, maxH - minH);
		const worldH = Math.max(2, maxV - minV);
		const margin = 24;
		const innerW = Math.max(50, width - margin * 2);
		const innerH = Math.max(50, height - margin * 2);
		const scale = Math.min(innerW / worldW, innerH / worldH);
		const drawnW = worldW * scale;
		const drawnH = worldH * scale;
		const offsetX = (width - drawnW) / 2;
		const offsetY = (height - drawnH) / 2;
		const originX = offsetX - minH * scale;
		const originY = height - offsetY + minV * scale;
		return {
			worldMin: { h: minH, v: minV },
			worldMax: { h: maxH, v: maxV },
			scale,
			originX,
			originY
		};
	}

	function worldToScreen(p, transform) {
		const proj = project(p, mode);
		return {
			x: transform.originX + proj.h * transform.scale,
			y: transform.originY - proj.v * transform.scale
		};
	}

	function render() {
		if (!canvasEl) return;
		const ctx = canvasEl.getContext('2d');
		if (!ctx) return;
		const theme = getThemeColors();
		const transform = computeTransform();

		ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		ctx.clearRect(0, 0, width, height);
		ctx.fillStyle = theme.bg;
		ctx.fillRect(0, 0, width, height);

		drawGrid(ctx, transform, theme);
		drawAxisLabels(ctx, transform, mode, theme);

		const positionsByTag = new Map();
		for (const p of positions) positionsByTag.set(p.tagId, p);

		for (const trail of trails) {
			const screenPoints = trail.points.map((pt) => ({
				...worldToScreen(pt.position, transform),
				ts: pt.timestamp,
				residual: pt.residual
			}));
			drawTrail(ctx, screenPoints, trail.color, {
				fadeFromAge: showTrailFade,
				highlightTs: cursorTs
			});
		}

		for (const a of anchors) {
			drawAnchor(ctx, worldToScreen(a.position, transform), a, theme);
		}
		for (const t of tags) {
			const tp = positionsByTag.get(t.id);
			const pos = tp?.position ?? t.position;
			const residual = tp?.residual ?? 0;
			drawTag(ctx, worldToScreen(pos, transform), t, theme, residual);
		}

		if (hover) {
			ctx.save();
			ctx.fillStyle = theme.bg;
			ctx.strokeStyle = theme.gridStrong;
			ctx.lineWidth = 1;
			const padding = 6;
			ctx.font = `12px ${theme.sans}`;
			const lines = hover.lines;
			const w = Math.max(...lines.map((l) => ctx.measureText(l).width)) + padding * 2;
			const h = lines.length * 16 + padding * 2;
			let bx = hover.x + 12;
			let by = hover.y + 12;
			if (bx + w > width) bx = hover.x - w - 12;
			if (by + h > height) by = hover.y - h - 12;
			ctx.fillRect(bx, by, w, h);
			ctx.strokeRect(bx, by, w, h);
			ctx.fillStyle = theme.text;
			ctx.textBaseline = 'top';
			lines.forEach((l, i) => ctx.fillText(l, bx + padding, by + padding + i * 16));
			ctx.restore();
		}
	}

	function onResize() {
		if (!wrapEl || !canvasEl) return;
		const rect = wrapEl.getBoundingClientRect();
		width = rect.width;
		height = Math.max(minHeight, rect.width * 0.6);
		dpr = window.devicePixelRatio || 1;
		canvasEl.width = width * dpr;
		canvasEl.height = height * dpr;
		canvasEl.style.width = `${width}px`;
		canvasEl.style.height = `${height}px`;
		render();
	}

	function onMove(ev) {
		const rect = canvasEl.getBoundingClientRect();
		const mx = ev.clientX - rect.left;
		const my = ev.clientY - rect.top;
		const transform = computeTransform();
		const positionsByTag = new Map();
		for (const p of positions) positionsByTag.set(p.tagId, p);

		const candidates = [
			...anchors.map((a) => ({
				kind: 'anchor',
				dev: a,
				screen: worldToScreen(a.position, transform),
				pos: a.position,
				residual: undefined
			})),
			...tags.map((t) => {
				const tp = positionsByTag.get(t.id);
				const pos = tp?.position ?? t.position;
				return {
					kind: 'tag',
					dev: t,
					screen: worldToScreen(pos, transform),
					pos,
					residual: tp?.residual
				};
			})
		];

		let best = null;
		let bestDist = 16;
		for (const c of candidates) {
			const dx = c.screen.x - mx;
			const dy = c.screen.y - my;
			const d = Math.sqrt(dx * dx + dy * dy);
			if (d < bestDist) {
				best = c;
				bestDist = d;
			}
		}

		if (best) {
			const { dev, pos, residual } = best;
			const lines = [
				`${dev.name}  (${best.kind === 'anchor' ? 'Anchor' : 'Tag'})`,
				`x: ${pos.x.toFixed(2)}  y: ${pos.y.toFixed(2)}  z: ${pos.z.toFixed(2)}`
			];
			if (residual !== undefined) lines.push(`residual: ${residual.toFixed(2)} m`);
			hover = { x: mx, y: my, lines };
		} else {
			hover = null;
		}
		render();
	}

	function onLeave() {
		hover = null;
		render();
	}

	// ---- mount/effects ----
	onMount(() => {
		const ro = new ResizeObserver(onResize);
		ro.observe(wrapEl);
		onResize();
		const themeObserver = new MutationObserver(render);
		themeObserver.observe(document.documentElement, {
			attributes: true,
			attributeFilter: ['data-theme']
		});
		return () => {
			ro.disconnect();
			themeObserver.disconnect();
		};
	});

	$effect(() => {
		void anchors;
		void tags;
		void positions;
		void trails;
		void mode;
		void cursorTs;
		void showTrailFade;
		render();
	});
</script>

<div class="wrap" bind:this={wrapEl} style:min-height="{minHeight}px">
	<canvas bind:this={canvasEl} onmousemove={onMove} onmouseleave={onLeave}></canvas>
</div>

<style>
	.wrap {
		position: relative;
		width: 100%;
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-lg);
		overflow: hidden;
	}
	canvas {
		display: block;
		width: 100%;
		height: 100%;
	}
</style>
