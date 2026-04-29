<script module>
	export function drawTrail(ctx, points, color, opts = {}) {
		if (!points?.length) return;
		const { fadeFromAge = false, maxAgeMs = 60000, now = Date.now(), highlightTs = null } = opts;
		ctx.save();
		ctx.lineWidth = 1.5;
		ctx.lineJoin = 'round';
		ctx.lineCap = 'round';

		for (let i = 1; i < points.length; i++) {
			const a = points[i - 1];
			const b = points[i];
			let alpha = 1;
			if (fadeFromAge) {
				const age = now - b.ts;
				alpha = Math.max(0.3, 1 - age / maxAgeMs);
			}
			const lowQ = (b.residual ?? 0) > 0.5;
			ctx.globalAlpha = alpha * (lowQ ? 0.5 : 1);
			ctx.strokeStyle = color;
			ctx.beginPath();
			ctx.moveTo(a.x, a.y);
			ctx.lineTo(b.x, b.y);
			ctx.stroke();
		}

		if (highlightTs !== null) {
			let cursor = points[0];
			for (const p of points) {
				if (p.ts <= highlightTs) cursor = p;
				else break;
			}
			ctx.globalAlpha = 1;
			ctx.fillStyle = color;
			ctx.beginPath();
			ctx.arc(cursor.x, cursor.y, 5, 0, Math.PI * 2);
			ctx.fill();
		}

		ctx.restore();
	}
</script>
