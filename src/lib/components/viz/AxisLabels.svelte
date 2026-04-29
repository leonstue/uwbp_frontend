<script module>
	const AXIS_LABELS = {
		xy: { h: 'X', v: 'Y' },
		xz: { h: 'X', v: 'Z' },
		yz: { h: 'Y', v: 'Z' }
	};

	export function drawAxisLabels(ctx, transform, mode, theme) {
		const labels = AXIS_LABELS[mode] ?? AXIS_LABELS.xy;
		const { worldMin, worldMax, scale, originX, originY } = transform;
		ctx.save();
		ctx.fillStyle = theme.muted;
		ctx.font = `12px ${theme.mono}`;
		ctx.textBaseline = 'middle';

		const startH = Math.ceil(worldMin.h);
		const endH = Math.floor(worldMax.h);
		ctx.textAlign = 'center';
		for (let h = startH; h <= endH; h++) {
			if (h === 0) continue;
			const x = originX + h * scale;
			ctx.fillText(String(h), x, ctx.canvas.height - 10);
		}

		const startV = Math.ceil(worldMin.v);
		const endV = Math.floor(worldMax.v);
		ctx.textAlign = 'left';
		for (let v = startV; v <= endV; v++) {
			if (v === 0) continue;
			const y = originY - v * scale;
			ctx.fillText(String(v), 6, y);
		}

		ctx.fillStyle = theme.text;
		ctx.font = `500 12px ${theme.sans}`;
		ctx.textAlign = 'right';
		ctx.fillText(`${labels.h} →`, ctx.canvas.width - 10, ctx.canvas.height - 10);
		ctx.textAlign = 'left';
		ctx.fillText(`↑ ${labels.v}`, 8, 14);
		ctx.restore();
	}
</script>
