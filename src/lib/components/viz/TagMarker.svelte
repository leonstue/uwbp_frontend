<script module>
	export function drawTag(ctx, screen, tag, theme, residual = 0) {
		const { x, y } = screen;
		const lowQuality = residual > 0.5;
		ctx.save();

		ctx.shadowColor = tag.color;
		ctx.shadowBlur = 14;
		ctx.fillStyle = tag.color;
		ctx.globalAlpha = lowQuality ? 0.6 : 1;
		ctx.beginPath();
		ctx.arc(x, y, 7, 0, Math.PI * 2);
		ctx.fill();
		ctx.shadowBlur = 0;

		if (lowQuality) {
			ctx.strokeStyle = theme.warn;
			ctx.lineWidth = 2;
			ctx.beginPath();
			ctx.arc(x, y, 9, 0, Math.PI * 2);
			ctx.stroke();
		}

		ctx.globalAlpha = 1;
		ctx.fillStyle = theme.text;
		ctx.font = `500 11px ${theme.sans}`;
		ctx.textAlign = 'left';
		ctx.textBaseline = 'middle';
		ctx.fillText(tag.name, x + 12, y);
		ctx.restore();
	}
</script>
