<script>
	import { onMount, onDestroy } from 'svelte';
	import PageHeader from '$lib/components/layout/PageHeader.svelte';
	import Card from '$lib/components/ui/Card.svelte';
	import Button from '$lib/components/ui/Button.svelte';
	import Input from '$lib/components/ui/Input.svelte';
	import Toggle from '$lib/components/ui/Toggle.svelte';
	import Play from 'lucide-svelte/icons/play';
	import Pause from 'lucide-svelte/icons/square';
	import Trash from 'lucide-svelte/icons/trash-2';
	import Download from 'lucide-svelte/icons/download';
	import Upload from 'lucide-svelte/icons/upload';

	// ---- table geometry (must match ApiClient mock) ----
	const TABLE = { x: 1.6, y: 0.8, z: 0.75 };
	const TAG_1_ID = '24:6F:28:B1:B2:88';
	const TAG_2_ID = '24:6F:28:C0:6A:04';

	// ---- state ----
	let canvasEl = $state(null);
	let wrapEl = $state(null);
	let width = $state(800);
	let height = $state(450);
	let raf = 0;

	let activeTag = $state('tag1');
	let startPos = $state({
		[TAG_1_ID]: { x: 0.4, y: 0.2, z: 0.78 },
		[TAG_2_ID]: { x: 1.2, y: 0.6, z: 0.78 }
	});
	let tracks = $state({ [TAG_1_ID]: [], [TAG_2_ID]: [] });
	let recording = $state(false);
	let recordingTag = $state(null);
	let recordingStartTs = 0;
	let previewActive = $state(false);
	let previewStartTs = 0;
	let liveTagPos = $state({
		[TAG_1_ID]: { x: 0.4, y: 0.2, z: 0.78 },
		[TAG_2_ID]: { x: 1.2, y: 0.6, z: 0.78 }
	});
	let pointerOnCanvas = $state(false);
	let pointerWorld = $state({ x: 0, y: 0, z: 0.78 });
	let pointerZ = $state(0.78);

	// ---- helpers ----
	function tagId(s) {
		return s === 'tag1' ? TAG_1_ID : TAG_2_ID;
	}

	function tagLabel(s) {
		return s === 'tag1' ? 'Tag-1' : 'Tag-2';
	}

	function loadFromStorage() {
		try {
			const raw = localStorage.getItem('uwbp.demoRecording');
			if (!raw) return;
			const parsed = JSON.parse(raw);
			if (parsed?.startPositions) {
				startPos = {
					[TAG_1_ID]: parsed.startPositions[TAG_1_ID] ?? startPos[TAG_1_ID],
					[TAG_2_ID]: parsed.startPositions[TAG_2_ID] ?? startPos[TAG_2_ID]
				};
			}
			if (parsed?.tracks) {
				tracks = {
					[TAG_1_ID]: parsed.tracks[TAG_1_ID] ?? [],
					[TAG_2_ID]: parsed.tracks[TAG_2_ID] ?? []
				};
			}
			liveTagPos = {
				[TAG_1_ID]: { ...startPos[TAG_1_ID] },
				[TAG_2_ID]: { ...startPos[TAG_2_ID] }
			};
		} catch {
			// ignore
		}
	}

	function saveToStorage() {
		const payload = {
			version: 1,
			tableSize: TABLE,
			startPositions: startPos,
			tracks
		};
		try {
			localStorage.setItem('uwbp.demoRecording', JSON.stringify(payload));
			window.dispatchEvent(new CustomEvent('uwbp:reload-recording'));
		} catch (e) {
			alert('Speichern fehlgeschlagen: ' + e.message);
		}
	}

	function clearAll() {
		if (!confirm('Komplette Aufnahme löschen?')) return;
		tracks = { [TAG_1_ID]: [], [TAG_2_ID]: [] };
		startPos = {
			[TAG_1_ID]: { x: 0.4, y: 0.2, z: 0.78 },
			[TAG_2_ID]: { x: 1.2, y: 0.6, z: 0.78 }
		};
		liveTagPos = {
			[TAG_1_ID]: { ...startPos[TAG_1_ID] },
			[TAG_2_ID]: { ...startPos[TAG_2_ID] }
		};
		try {
			localStorage.removeItem('uwbp.demoRecording');
			window.dispatchEvent(new CustomEvent('uwbp:reload-recording'));
		} catch {
			// ignore
		}
	}

	function clearTrack(s) {
		const id = tagId(s);
		tracks = { ...tracks, [id]: [] };
		liveTagPos = { ...liveTagPos, [id]: { ...startPos[id] } };
		saveToStorage();
	}

	function exportJson() {
		const payload = { version: 1, tableSize: TABLE, startPositions: startPos, tracks };
		const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `uwbp-demo-${Date.now()}.json`;
		a.click();
		URL.revokeObjectURL(url);
	}

	function importJsonFile(e) {
		const file = e.target.files?.[0];
		if (!file) return;
		const reader = new FileReader();
		reader.onload = () => {
			try {
				const parsed = JSON.parse(String(reader.result));
				if (parsed?.startPositions) {
					startPos = {
						[TAG_1_ID]: parsed.startPositions[TAG_1_ID] ?? startPos[TAG_1_ID],
						[TAG_2_ID]: parsed.startPositions[TAG_2_ID] ?? startPos[TAG_2_ID]
					};
				}
				if (parsed?.tracks) {
					tracks = {
						[TAG_1_ID]: parsed.tracks[TAG_1_ID] ?? [],
						[TAG_2_ID]: parsed.tracks[TAG_2_ID] ?? []
					};
				}
				saveToStorage();
				liveTagPos = {
					[TAG_1_ID]: { ...startPos[TAG_1_ID] },
					[TAG_2_ID]: { ...startPos[TAG_2_ID] }
				};
			} catch (err) {
				alert('Import fehlgeschlagen: ' + err.message);
			}
		};
		reader.readAsText(file);
	}

	// ---- recording ----
	function startRecording(s) {
		if (previewActive) stopPreview();
		const id = tagId(s);
		tracks = { ...tracks, [id]: [] };
		recordingTag = s;
		recording = true;
		recordingStartTs = performance.now();
		liveTagPos = {
			...liveTagPos,
			[id]: { ...startPos[id] }
		};
	}

	function stopRecording() {
		if (!recording) return;
		recording = false;
		recordingTag = null;
		saveToStorage();
	}

	function recordSample() {
		if (!recording || !recordingTag) return;
		const id = tagId(recordingTag);
		const t = performance.now() - recordingStartTs;
		const arr = tracks[id];
		arr.push({
			t: Math.round(t),
			x: liveTagPos[id].x,
			y: liveTagPos[id].y,
			z: liveTagPos[id].z
		});
		tracks = { ...tracks, [id]: arr };
	}

	// ---- preview ----
	function startPreview() {
		if (recording) return;
		previewActive = true;
		previewStartTs = performance.now();
	}

	function stopPreview() {
		previewActive = false;
		liveTagPos = {
			[TAG_1_ID]: { ...startPos[TAG_1_ID] },
			[TAG_2_ID]: { ...startPos[TAG_2_ID] }
		};
	}

	function trackPosAt(id, ms) {
		const track = tracks[id];
		if (!track?.length) return { ...startPos[id] };
		const dur = track[track.length - 1].t;
		if (ms >= dur) {
			const last = track[track.length - 1];
			return { x: last.x, y: last.y, z: last.z };
		}
		if (ms <= track[0].t) {
			return { x: track[0].x, y: track[0].y, z: track[0].z };
		}
		let lo = 0;
		let hi = track.length - 1;
		while (lo + 1 < hi) {
			const mid = (lo + hi) >> 1;
			if (track[mid].t <= ms) lo = mid;
			else hi = mid;
		}
		const a = track[lo];
		const b = track[hi];
		const k = (ms - a.t) / Math.max(1, b.t - a.t);
		return {
			x: a.x + (b.x - a.x) * k,
			y: a.y + (b.y - a.y) * k,
			z: a.z + (b.z - a.z) * k
		};
	}

	// ---- canvas: coords ----
	function worldToCanvas(p) {
		const m = 20;
		const sx = (width - m * 2) / TABLE.x;
		const sy = (height - m * 2) / TABLE.y;
		const s = Math.min(sx, sy);
		const drawnW = TABLE.x * s;
		const drawnH = TABLE.y * s;
		const ox = (width - drawnW) / 2;
		const oy = (height - drawnH) / 2;
		return {
			x: ox + p.x * s,
			y: height - oy - p.y * s,
			s
		};
	}

	function canvasToWorld(cx, cy) {
		const m = 20;
		const sx = (width - m * 2) / TABLE.x;
		const sy = (height - m * 2) / TABLE.y;
		const s = Math.min(sx, sy);
		const drawnW = TABLE.x * s;
		const drawnH = TABLE.y * s;
		const ox = (width - drawnW) / 2;
		const oy = (height - drawnH) / 2;
		return {
			x: Math.max(0, Math.min(TABLE.x, (cx - ox) / s)),
			y: Math.max(0, Math.min(TABLE.y, (height - oy - cy) / s))
		};
	}

	function getThemeColors() {
		const cs = getComputedStyle(document.documentElement);
		return {
			bg: cs.getPropertyValue('--bg-secondary').trim() || '#131922',
			grid: cs.getPropertyValue('--border').trim() || '#2A3444',
			text: cs.getPropertyValue('--text-primary').trim() || '#E6EDF3',
			muted: cs.getPropertyValue('--text-muted').trim() || '#5C6877',
			accent: cs.getPropertyValue('--accent').trim() || '#4F8EFF'
		};
	}

	// ---- render ----
	function render() {
		if (!canvasEl) return;
		const ctx = canvasEl.getContext('2d');
		if (!ctx) return;
		const theme = getThemeColors();
		const dpr = window.devicePixelRatio || 1;
		ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
		ctx.clearRect(0, 0, width, height);
		ctx.fillStyle = theme.bg;
		ctx.fillRect(0, 0, width, height);

		// table outline
		const tl = worldToCanvas({ x: 0, y: TABLE.y });
		const br = worldToCanvas({ x: TABLE.x, y: 0 });
		ctx.strokeStyle = theme.grid;
		ctx.lineWidth = 2;
		ctx.strokeRect(tl.x, tl.y, br.x - tl.x, br.y - tl.y);

		// 0.1m grid
		ctx.strokeStyle = theme.grid;
		ctx.lineWidth = 0.5;
		ctx.globalAlpha = 0.5;
		for (let gx = 0.1; gx < TABLE.x; gx += 0.1) {
			const a = worldToCanvas({ x: gx, y: 0 });
			const b = worldToCanvas({ x: gx, y: TABLE.y });
			ctx.beginPath();
			ctx.moveTo(a.x, a.y);
			ctx.lineTo(b.x, b.y);
			ctx.stroke();
		}
		for (let gy = 0.1; gy < TABLE.y; gy += 0.1) {
			const a = worldToCanvas({ x: 0, y: gy });
			const b = worldToCanvas({ x: TABLE.x, y: gy });
			ctx.beginPath();
			ctx.moveTo(a.x, a.y);
			ctx.lineTo(b.x, b.y);
			ctx.stroke();
		}
		ctx.globalAlpha = 1;

		// anchors at corners
		const anchorColors = ['#34D399', '#4F8EFF', '#FBBF24', '#F472B6'];
		const anchorPositions = [
			{ x: 0, y: 0 },
			{ x: TABLE.x, y: 0 },
			{ x: TABLE.x, y: TABLE.y },
			{ x: 0, y: TABLE.y }
		];
		for (let i = 0; i < anchorPositions.length; i++) {
			const p = worldToCanvas(anchorPositions[i]);
			ctx.fillStyle = anchorColors[i];
			ctx.beginPath();
			ctx.arc(p.x, p.y, 6, 0, Math.PI * 2);
			ctx.fill();
			ctx.fillStyle = theme.muted;
			ctx.font = '11px ui-sans-serif';
			ctx.fillText(`A${i + 1}`, p.x + 10, p.y - 6);
		}

		// existing tracks (dim)
		for (const s of ['tag1', 'tag2']) {
			const id = tagId(s);
			const track = tracks[id];
			if (!track || track.length < 2) continue;
			ctx.strokeStyle = s === 'tag1' ? '#A78BFA' : '#22D3EE';
			ctx.globalAlpha = recordingTag === s ? 0.25 : 0.6;
			ctx.lineWidth = 1.5;
			ctx.beginPath();
			for (let i = 0; i < track.length; i++) {
				const p = worldToCanvas(track[i]);
				if (i === 0) ctx.moveTo(p.x, p.y);
				else ctx.lineTo(p.x, p.y);
			}
			ctx.stroke();
		}
		ctx.globalAlpha = 1;

		// current tag positions
		for (const s of ['tag1', 'tag2']) {
			const id = tagId(s);
			const pos = liveTagPos[id];
			const p = worldToCanvas(pos);
			const color = s === 'tag1' ? '#A78BFA' : '#22D3EE';
			ctx.fillStyle = color;
			ctx.shadowColor = color;
			ctx.shadowBlur = 12;
			ctx.beginPath();
			ctx.arc(p.x, p.y, 8, 0, Math.PI * 2);
			ctx.fill();
			ctx.shadowBlur = 0;
			ctx.fillStyle = theme.text;
			ctx.font = '12px ui-sans-serif';
			ctx.fillText(`${tagLabel(s)} z=${pos.z.toFixed(2)}`, p.x + 12, p.y - 8);
		}

		// pointer crosshair
		if (pointerOnCanvas && (recording || !previewActive)) {
			const p = worldToCanvas(pointerWorld);
			ctx.strokeStyle = theme.accent;
			ctx.globalAlpha = 0.5;
			ctx.lineWidth = 1;
			ctx.beginPath();
			ctx.moveTo(p.x - 10, p.y);
			ctx.lineTo(p.x + 10, p.y);
			ctx.moveTo(p.x, p.y - 10);
			ctx.lineTo(p.x, p.y + 10);
			ctx.stroke();
			ctx.globalAlpha = 1;
		}

		// rec indicator
		if (recording) {
			ctx.fillStyle = '#EF4444';
			ctx.beginPath();
			ctx.arc(20, 20, 6, 0, Math.PI * 2);
			ctx.fill();
			ctx.fillStyle = theme.text;
			ctx.font = '12px ui-sans-serif';
			const elapsed = ((performance.now() - recordingStartTs) / 1000).toFixed(1);
			ctx.fillText(
				`REC ${tagLabel(recordingTag)}  ${elapsed}s  (samples: ${tracks[tagId(recordingTag)].length})`,
				32,
				24
			);
		} else if (previewActive) {
			ctx.fillStyle = theme.accent;
			ctx.beginPath();
			ctx.arc(20, 20, 6, 0, Math.PI * 2);
			ctx.fill();
			ctx.fillStyle = theme.text;
			ctx.font = '12px ui-sans-serif';
			const dur = Math.max(
				tracks[TAG_1_ID]?.[tracks[TAG_1_ID].length - 1]?.t ?? 0,
				tracks[TAG_2_ID]?.[tracks[TAG_2_ID].length - 1]?.t ?? 0
			);
			const elapsed = performance.now() - previewStartTs;
			ctx.fillText(
				`PREVIEW  ${(elapsed / 1000).toFixed(1)}s / ${(dur / 1000).toFixed(1)}s`,
				32,
				24
			);
		}
	}

	// ---- main loop ----
	function loop() {
		const now = performance.now();

		if (recording && recordingTag) {
			const id = tagId(recordingTag);
			liveTagPos = {
				...liveTagPos,
				[id]: { x: pointerWorld.x, y: pointerWorld.y, z: pointerZ }
			};
			// overdub: other tag plays back if it has a track
			const otherId = id === TAG_1_ID ? TAG_2_ID : TAG_1_ID;
			if (tracks[otherId]?.length > 0) {
				const elapsed = now - recordingStartTs;
				liveTagPos = { ...liveTagPos, [otherId]: trackPosAt(otherId, elapsed) };
			}
			recordSample();
		} else if (previewActive) {
			const elapsed = now - previewStartTs;
			const dur = Math.max(
				tracks[TAG_1_ID]?.[tracks[TAG_1_ID].length - 1]?.t ?? 0,
				tracks[TAG_2_ID]?.[tracks[TAG_2_ID].length - 1]?.t ?? 0
			);
			if (dur > 0 && elapsed > dur + 500) {
				stopPreview();
			} else {
				liveTagPos = {
					[TAG_1_ID]: trackPosAt(TAG_1_ID, elapsed),
					[TAG_2_ID]: trackPosAt(TAG_2_ID, elapsed)
				};
			}
		}

		render();
		raf = requestAnimationFrame(loop);
	}

	function onResize() {
		if (!wrapEl || !canvasEl) return;
		const rect = wrapEl.getBoundingClientRect();
		const dpr = window.devicePixelRatio || 1;
		width = Math.max(300, Math.floor(rect.width));
		height = Math.max(300, Math.floor(rect.width * 0.55));
		canvasEl.width = width * dpr;
		canvasEl.height = height * dpr;
		canvasEl.style.width = `${width}px`;
		canvasEl.style.height = `${height}px`;
	}

	function onPointerDown(e) {
		const rect = canvasEl.getBoundingClientRect();
		const cx = e.clientX - rect.left;
		const cy = e.clientY - rect.top;
		const w = canvasToWorld(cx, cy);
		pointerOnCanvas = true;
		pointerWorld = { x: w.x, y: w.y, z: pointerZ };
		canvasEl.setPointerCapture(e.pointerId);
		if (!recording && !previewActive) {
			// start recording on click on active tag
			startRecording(activeTag);
		}
	}

	function onPointerMove(e) {
		const rect = canvasEl.getBoundingClientRect();
		const cx = e.clientX - rect.left;
		const cy = e.clientY - rect.top;
		pointerOnCanvas =
			cx >= 0 && cx <= rect.width && cy >= 0 && cy <= rect.height;
		const w = canvasToWorld(cx, cy);
		pointerWorld = { x: w.x, y: w.y, z: pointerZ };
	}

	function onPointerUp(e) {
		try {
			canvasEl.releasePointerCapture(e.pointerId);
		} catch {
			// ignore
		}
		if (recording) stopRecording();
	}

	function onPointerLeave() {
		pointerOnCanvas = false;
	}

	function onWheel(e) {
		e.preventDefault();
		const delta = e.deltaY > 0 ? -0.02 : 0.02;
		pointerZ = Math.max(0.5, Math.min(1.5, pointerZ + delta));
		pointerWorld = { ...pointerWorld, z: pointerZ };
	}

	function setStartFromCurrentPointer(s) {
		const id = tagId(s);
		startPos = {
			...startPos,
			[id]: { x: pointerWorld.x, y: pointerWorld.y, z: pointerZ }
		};
		liveTagPos = { ...liveTagPos, [id]: { ...startPos[id] } };
		saveToStorage();
	}

	function updateStartCoord(s, axis, value) {
		const id = tagId(s);
		const next = { ...startPos[id], [axis]: Number(value) };
		startPos = { ...startPos, [id]: next };
		if (!recording && !previewActive) {
			liveTagPos = { ...liveTagPos, [id]: { ...next } };
		}
		saveToStorage();
	}

	// ---- mount ----
	onMount(() => {
		loadFromStorage();
		const ro = new ResizeObserver(onResize);
		ro.observe(wrapEl);
		onResize();
		raf = requestAnimationFrame(loop);
		return () => {
			ro.disconnect();
			cancelAnimationFrame(raf);
		};
	});

	onDestroy(() => {
		if (typeof cancelAnimationFrame !== 'undefined') {
			cancelAnimationFrame(raf);
		}
	});

	// ---- derived ----
	let dur1 = $derived(tracks[TAG_1_ID]?.[tracks[TAG_1_ID].length - 1]?.t ?? 0);
	let dur2 = $derived(tracks[TAG_2_ID]?.[tracks[TAG_2_ID].length - 1]?.t ?? 0);
	let samples1 = $derived(tracks[TAG_1_ID]?.length ?? 0);
	let samples2 = $derived(tracks[TAG_2_ID]?.length ?? 0);
</script>

<PageHeader title="Demo-Aufnahme" subtitle="Bewegungsdaten für Mock-Replay aufnehmen" />

<Card>
	<div class="info">
		<p>
			Tisch <span class="mono">{TABLE.x} × {TABLE.y} m, Anchors auf {TABLE.z} m</span>. Klick + Halten
			auf der Fläche zeichnet die Bewegung des aktiven Tags auf. Mausrad ändert die Höhe (z).
			Loslassen stoppt die Aufnahme.
		</p>
		<p class="hint">
			Hat ein Tag bereits eine Aufnahme, läuft sie beim Aufnehmen des anderen Tags parallel mit
			(Overdub). So kannst du beide Tags synchron animieren.
		</p>
	</div>
</Card>

<div class="layout">
	<aside class="controls">
		<Card>
			{#snippet header()}<span>Aktiver Tag</span>{/snippet}
			<div class="seg">
				<button
					type="button"
					class="seg-btn"
					class:active={activeTag === 'tag1'}
					onclick={() => (activeTag = 'tag1')}
				>
					Tag-1
				</button>
				<button
					type="button"
					class="seg-btn"
					class:active={activeTag === 'tag2'}
					onclick={() => (activeTag = 'tag2')}
				>
					Tag-2
				</button>
			</div>
			<div class="row-end">
				{#if recording}
					<Button variant="danger" size="sm" onclick={stopRecording}>
						<Pause size={14} /> Aufnahme stoppen
					</Button>
				{:else}
					<Button size="sm" onclick={() => startRecording(activeTag)}>
						<Play size={14} /> Aufnehmen ({tagLabel(activeTag)})
					</Button>
				{/if}
			</div>
		</Card>

		<Card>
			{#snippet header()}<span>Startpositionen</span>{/snippet}
			<div class="col">
				{#each ['tag1', 'tag2'] as tagSlot (tagSlot)}
					{@const id = tagId(tagSlot)}
					<div class="start-row">
						<span class="lbl">{tagLabel(tagSlot)}</span>
						<div class="xyz">
							<Input
								label="x"
								type="number"
								step="0.01"
								value={startPos[id].x}
								oninput={(e) => updateStartCoord(tagSlot, 'x', e.target.value)}
							/>
							<Input
								label="y"
								type="number"
								step="0.01"
								value={startPos[id].y}
								oninput={(e) => updateStartCoord(tagSlot, 'y', e.target.value)}
							/>
							<Input
								label="z"
								type="number"
								step="0.01"
								value={startPos[id].z}
								oninput={(e) => updateStartCoord(tagSlot, 'z', e.target.value)}
							/>
						</div>
						<Button variant="ghost" size="sm" onclick={() => setStartFromCurrentPointer(tagSlot)}>
							Von Maus übernehmen
						</Button>
					</div>
				{/each}
			</div>
		</Card>

		<Card>
			{#snippet header()}<span>Vorschau</span>{/snippet}
			<div class="row-end">
				{#if previewActive}
					<Button variant="secondary" size="sm" onclick={stopPreview}>Stoppen</Button>
				{:else}
					<Button
						size="sm"
						onclick={startPreview}
						disabled={samples1 === 0 && samples2 === 0}
					>
						<Play size={14} /> Vorschau abspielen
					</Button>
				{/if}
			</div>
		</Card>

		<Card>
			{#snippet header()}<span>Datei</span>{/snippet}
			<div class="col">
				<div class="row-end">
					<Button variant="secondary" size="sm" onclick={exportJson}>
						<Download size={14} /> Export JSON
					</Button>
					<label class="import-label">
						<Upload size={14} /> Import JSON
						<input
							type="file"
							accept="application/json"
							onchange={importJsonFile}
							class="sr-only"
						/>
					</label>
				</div>
				<div class="row-between">
					<Button variant="ghost" size="sm" onclick={() => clearTrack('tag1')}>
						<Trash size={14} /> Tag-1 löschen
					</Button>
					<Button variant="ghost" size="sm" onclick={() => clearTrack('tag2')}>
						<Trash size={14} /> Tag-2 löschen
					</Button>
				</div>
				<div class="row-end">
					<Button variant="danger" size="sm" onclick={clearAll}>
						<Trash size={14} /> Alles löschen
					</Button>
				</div>
			</div>
		</Card>

		<Card>
			{#snippet header()}<span>Status</span>{/snippet}
			<dl class="stats mono">
				<div>
					<dt>Tag-1</dt>
					<dd>{samples1} Samples · {(dur1 / 1000).toFixed(2)}s</dd>
				</div>
				<div>
					<dt>Tag-2</dt>
					<dd>{samples2} Samples · {(dur2 / 1000).toFixed(2)}s</dd>
				</div>
				<div>
					<dt>Maus-Z</dt>
					<dd>{pointerZ.toFixed(2)} m</dd>
				</div>
			</dl>
			<p class="hint">Hotkeys im Hauptbetrieb: Strg+Shift+P startet Replay, +L loopt, +R resettet.</p>
		</Card>
	</aside>

	<div class="canvas-wrap" bind:this={wrapEl}>
		<canvas
			bind:this={canvasEl}
			onpointerdown={onPointerDown}
			onpointermove={onPointerMove}
			onpointerup={onPointerUp}
			onpointerleave={onPointerLeave}
			onwheel={onWheel}
		></canvas>
	</div>
</div>

<style>
	.info {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}
	.info p {
		margin: 0;
		color: var(--text-secondary);
		font-size: var(--text-sm);
		line-height: 1.5;
	}
	.hint {
		color: var(--text-muted);
		font-size: var(--text-xs);
	}
	.mono {
		font-family: var(--font-mono);
	}
	.layout {
		margin-top: var(--space-4);
		display: grid;
		grid-template-columns: 320px 1fr;
		gap: var(--space-4);
		align-items: start;
	}
	@media (max-width: 900px) {
		.layout {
			grid-template-columns: 1fr;
		}
	}
	.controls {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.canvas-wrap {
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-lg);
		overflow: hidden;
	}
	canvas {
		display: block;
		touch-action: none;
		cursor: crosshair;
	}
	.col {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}
	.row-end {
		display: flex;
		justify-content: flex-end;
		gap: var(--space-2);
		flex-wrap: wrap;
	}
	.row-between {
		display: flex;
		justify-content: space-between;
		gap: var(--space-2);
		flex-wrap: wrap;
	}
	.seg {
		display: flex;
		gap: 2px;
		padding: 4px;
		background: var(--bg-tertiary);
		border-radius: var(--radius-md);
		margin-bottom: var(--space-3);
	}
	.seg-btn {
		flex: 1;
		padding: var(--space-2);
		border-radius: var(--radius-sm);
		color: var(--text-secondary);
		font-weight: 500;
		font-size: var(--text-sm);
	}
	.seg-btn.active {
		background: var(--bg-secondary);
		color: var(--accent);
	}
	.start-row {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding-bottom: var(--space-3);
		border-bottom: 1px solid var(--border);
	}
	.start-row:last-child {
		border-bottom: none;
		padding-bottom: 0;
	}
	.lbl {
		font-weight: 500;
		color: var(--text-primary);
		font-size: var(--text-sm);
	}
	.xyz {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-2);
	}
	.stats {
		margin: 0;
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		font-size: var(--text-xs);
	}
	.stats > div {
		display: flex;
		justify-content: space-between;
	}
	.stats dt {
		color: var(--text-muted);
	}
	.stats dd {
		margin: 0;
		color: var(--text-primary);
	}
	.import-label {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: var(--space-2) var(--space-3);
		background: var(--bg-secondary);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		font-size: var(--text-xs);
		font-weight: 500;
		color: var(--text-primary);
		cursor: pointer;
	}
	.import-label:hover {
		border-color: var(--border-strong);
	}
</style>
