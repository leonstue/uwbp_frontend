<script module>
	export function drawAnchor(ctx, screen, anchor, theme) {
		const { x, y } = screen;
		ctx.save();
		ctx.fillStyle = anchor.color;
		ctx.strokeStyle = theme.bg;
		ctx.lineWidth = 2;
		ctx.beginPath();
		ctx.arc(x, y, 6, 0, Math.PI * 2);
		ctx.fill();
		ctx.stroke();

		ctx.fillStyle = theme.text;
		ctx.font = `500 11px ${theme.sans}`;
		ctx.textAlign = 'left';
		ctx.textBaseline = 'middle';
		ctx.fillText(anchor.name, x + 10, y);
		ctx.restore();
	}
</script>
