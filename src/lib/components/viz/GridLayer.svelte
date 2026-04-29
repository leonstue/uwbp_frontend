<script module>
	export function drawGrid(ctx, transform, theme) {
		const { worldMin, worldMax, scale, originX, originY } = transform;
		ctx.save();
		ctx.lineWidth = 1;
		ctx.strokeStyle = theme.grid;
		ctx.beginPath();
		const startH = Math.floor(worldMin.h);
		const endH = Math.ceil(worldMax.h);
		for (let h = startH; h <= endH; h++) {
			const x = originX + h * scale;
			ctx.moveTo(x, 0);
			ctx.lineTo(x, ctx.canvas.height);
		}
		const startV = Math.floor(worldMin.v);
		const endV = Math.ceil(worldMax.v);
		for (let v = startV; v <= endV; v++) {
			const y = originY - v * scale;
			ctx.moveTo(0, y);
			ctx.lineTo(ctx.canvas.width, y);
		}
		ctx.stroke();

		ctx.lineWidth = 1.5;
		ctx.strokeStyle = theme.gridStrong;
		ctx.beginPath();
		ctx.moveTo(originX, 0);
		ctx.lineTo(originX, ctx.canvas.height);
		ctx.moveTo(0, originY);
		ctx.lineTo(ctx.canvas.width, originY);
		ctx.stroke();
		ctx.restore();
	}
</script>
