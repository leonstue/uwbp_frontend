<script module>
	export function drawTrail(ctx, points, color, opts = {}) {
		if (!points?.length) return;
		const { fadeFromAge = false, now = Date.now(), highlightTs = null } = opts;
		ctx.save();
		ctx.lineJoin = 'round';
		ctx.lineCap = 'round';

		const visible = highlightTs !== null ? points.filter((p) => p.ts <= highlightTs) : points;
		if (visible.length < 1) {
			ctx.restore();
			return;
		}

		const oldest = visible[0]?.ts ?? now;
		const ref = highlightTs !== null ? highlightTs : now;
		const span = Math.max(500, ref - oldest);

		for (let i = 1; i < visible.length; i++) {
			const a = visible[i - 1];
			const b = visible[i];
			let alpha = 1;
			let lineW = 1.5;
			if (fadeFromAge) {
				const age = ref - b.ts;
				const t = 1 - age / span;
				alpha = Math.max(0.05, t);
				lineW = 1 + 1.5 * t;
			}
			const dx = b.x - a.x;
			const dy = b.y - a.y;
			const dist = Math.sqrt(dx * dx + dy * dy);
			const dt = Math.max(16, b.ts - a.ts);
			const pxPerMs = dist / dt;
			const speedFactor = Math.max(0.55, Math.min(1.6, 1 - (pxPerMs - 0.1) * 2.5));
			lineW *= speedFactor;
			alpha *= 0.75 + 0.35 * (speedFactor - 0.55);
			alpha = Math.min(1, alpha);
			const lowQ = (b.residual ?? 0) > 0.5;
			ctx.globalAlpha = alpha * (lowQ ? 0.5 : 1);
			ctx.lineWidth = lineW;
			ctx.strokeStyle = color;
			ctx.beginPath();
			ctx.moveTo(a.x, a.y);
			ctx.lineTo(b.x, b.y);
			ctx.stroke();
		}

		if (highlightTs !== null) {
			const cursor = visible[visible.length - 1];
			ctx.globalAlpha = 1;
			ctx.fillStyle = color;
			ctx.beginPath();
			ctx.arc(cursor.x, cursor.y, 5, 0, Math.PI * 2);
			ctx.fill();
		}

		ctx.restore();
	}
</script>
