# UWBP Frontend — Vollständige Spezifikation

## Kontext

Frontend für ein UWB-Indoor-Positioning-System. Ein Raspberry Pi 5 hostet ein eigenes WLAN ("UWBP"), an das sich ESP32-Devices (Anchors + Tags) und der User-Browser verbinden. Der C++ Backend-Server läuft bereits und stellt eine REST-API bereit. Das Frontend ist die Bedienoberfläche zum Konfigurieren der Devices und Visualisieren der Positionsdaten.

## Tech-Stack

- **Svelte 5** mit **Runes-Mode** (`$state`, `$derived`, `$effect`, `$props`, `$bindable`)
- **SvelteKit** (Setup über `npx sv create`)
- **JavaScript** (kein TypeScript). JSDoc-Annotationen optional für Type-Hints in der IDE
- **Vite** (von SvelteKit fest eingebaut, nicht optional)
- **Pures CSS** mit Svelte-scoped `<style>`-Blöcken und globalen CSS-Variablen für Theming. **Kein Tailwind**, kein CSS-Framework
- Läuft als eigener Node-Prozess auf dem Pi (separater Port vom Backend)
- Macht REST-Calls an den C++ Backend-Server
- **Pollt periodisch** — das Backend bietet aktuell nur klassische REST-Endpoints, kein SSE oder WebSocket. SSE-Stream-Endpoint ist für später im Backend-Plan vorgesehen, das Frontend kann dann optional darauf umstellen
- Adapter für Production: `@sveltejs/adapter-node` (statt dem Default `adapter-auto`)

## Erreichbarkeit / Domain-Konzept

Der Pi ist nur erreichbar wenn der User mit dem WLAN "UWBP" verbunden ist (Passwort: `abcd1234`). Innerhalb des WLANs:

- Pi-IP: `10.42.0.1`
- DNS-Alias: `uwbp` (via dnsmasq auf dem Pi konfiguriert, kein `.local` nötig)

**Vorgeschlagene Port-Aufteilung:**

| Service | Port | URL |
|---------|------|-----|
| C++ Backend (REST) | `8080` | `http://uwbp:8080` |
| SvelteKit Frontend | `3000` | `http://uwbp:3000` |

**Empfehlung für saubere User-Experience:**
Frontend auf Port `80` laufen lassen (per `setcap` damit kein root nötig), dann reicht dem User `http://uwbp` im Browser einzugeben. Alternativ ein iptables-Redirect 80 → 3000.

```bash
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j REDIRECT --to-port 3000
```

Die Backend-API bleibt bei `8080`. Frontend macht intern fetch-Calls an `http://uwbp:8080/api/...`. Bei separaten Origins muss CORS im Backend erlaubt werden (siehe "Backend-Erweiterungen").

## Zugriffsablauf für den User

1. User verbindet sich mit WLAN `UWBP` (Passwort `abcd1234`)
2. User öffnet Browser → `http://uwbp` (oder `http://uwbp:3000`)
3. Frontend lädt, holt sich Daten vom Backend
4. Beim ersten Start: Setup-Wizard führt durch Anchor-/Tag-Konfiguration
5. Danach: Dashboard mit Live-Daten, History abrufbar

## Funktionsumfang

### 1. Setup-Wizard (`/setup`)

**Zweck:** Geführte Erstkonfiguration. Wird automatisch angezeigt wenn noch keine Anchor-Positionen gesetzt sind.

**Schritte:**

1. **Willkommen** — Kurze Erklärung, "Schalte jetzt deine Anchors ein"
2. **Anchors warten** — Live-Counter "2 von 3 verbunden", Liste der eingehenden Registrierungen mit ID
3. **Anchors benennen** — Jedem Anchor Name + Farbe geben (Color-Picker)
4. **Anchor-Positionen** — x/y/z eintragen für jeden Anchor, Live-Vorschau im Raum (Draufsicht)
5. **Tags warten** — Counter wie bei Anchors, "Schalte deine Tags ein"
6. **Tags benennen** — Name + Farbe pro Tag
7. **Fertig** — Weiterleitung zum Dashboard

**Logik:**
- Polling auf `GET /api/devices` während Wizard läuft, um neu registrierte Devices live anzuzeigen
- "Weiter"-Button erst aktiv wenn Mindestbedingung erfüllt (z.B. ≥3 Anchors)
- Bricht User ab → springt direkt ins Dashboard, Wizard kann später aus Settings neu gestartet werden

### 2. Live-Dashboard (`/`)

**Zweck:** Echtzeit-Übersicht über alle registrierten Devices und aktuelle Tag-Positionen.

**Layout:**
- **Statusleiste oben:** Server-Health, Anzahl verbundener Anchors, Anzahl Tags, aktuelle Polling-Rate, **Run-State-Toggle** (Läuft/Gestoppt)
- **Hauptbereich (rechteckiges Visualisierungselement):** siehe "Visualisierungselement" weiter unten
- **Rechte Sidebar — Alive-Ansicht:** Liste aller Devices (Anchors + Tags) mit:
  - Status-Indikator (Ampelfarbe, siehe unten)
  - Gerätename + Color-Dot
  - Aktuelle Position (x, y, z)
  - "Last seen vor 2s" (relative Zeit)
  - Residual als Qualitätsindikator (nur Tags)

**Status-Farben (Alive-Ansicht):**

| Status | Bedingung (lastSeen-Alter) | Farbe |
|--------|---------------------------|-------|
| Online | < 5 Sekunden | Grün |
| Verzögert | 5-30 Sekunden | Gelb |
| Offline | > 30 Sekunden | Rot |

Status kommt aus dem Backend (`device.status`) oder wird im Frontend aus `device.lastSeen` berechnet.

**Run-State (Live-Ansicht starten/beenden):**
- **Läuft** (grün) → Polling aktiv, Tags bewegen sich, History-Buffer wird befüllt
- **Gestoppt** (grau) → Polling pausiert, Visualisierung eingefroren auf letztem Frame
- Beim Stoppen: Hinweis-Banner "Live-Ansicht pausiert. Daten werden weiter im Hintergrund vom Server gesammelt."
- Backend läuft unverändert weiter — Stoppen betrifft nur das Frontend

**Polling:**
- `GET /api/positions` alle 100-200ms (Live-Positionen)
- `GET /api/devices` alle 1-2s (Status-/lastSeen-Updates)

### 3. Geräte-Verwaltung (`/devices`)

**Zweck:** Alle registrierten ESP32s sehen, ihnen Namen und Farben geben, Status prüfen.

**Inhalte:**
- Tabelle/Liste mit allen Devices (Polling auf `GET /api/devices` alle 2-5s)
- Spalten:
  - **Status** (Ampel-Dot mit Tooltip "Online / vor 2s")
  - **ID** (MAC)
  - **Type** (Anchor/Tag, Badge)
  - **Name** (editierbar, Inline-Save)
  - **Farbe** (Color-Picker, Inline-Save)
  - **Last Seen** ("vor 3s", auto-refresh)
  - **Aktuelle Position** (read-only)
  - **Aktionen** (Vergessen-Button → `DELETE /api/devices/{id}`)
- Zwei Tabs / Filter: "Anchors" und "Tags" zur Übersichtlichkeit
- Speichern via `PUT /api/devices/{id}` mit `{name, color}`

### 4. Anchor-Kalibrierung (`/anchors`)

**Zweck:** Position der Anchors im Raum eintragen, ohne diese kann das System nicht trilaterieren.

**Inhalte:**
- Liste aller Anchors mit Eingabefeldern für x, y, z (Meter)
- Status-Dot pro Anchor (Online/Offline)
- Live-Vorschau: rechteckiges Visualisierungselement mit Anchor-Positionen, aktualisiert sich beim Tippen
- Speichern-Button pro Anchor → `PUT /api/anchors/{id}/position`
- Hilfetext: "X = Breite, Y = Tiefe, Z = Höhe (alles in Metern, Ursprung im Raumeck)"
- Validierung: numerische Werte, Hinweis wenn 2+ Anchors die exakt gleiche Position haben (Trilateration scheitert dann)
- Vorlagen-Button für übliche Layouts (Rechteck-Ecken, Dreieck) füllt Werte vor

### 5. History / Zeitlicher Verlauf (`/history`)

**Zweck:** Bewegung der Tags über Zeit visualisieren.

**Inhalte:**
- **Multi-Select für Tags** (Checkboxes mit Color-Dot): User wählt einen oder mehrere Tags aus, jeweils in eigener Farbe
- **Zeitraum-Auswahl:** "letzte 1min / 5min / 15min / 1h" oder Custom-Range mit Datepicker
- **Hauptbereich:** rechteckiges Visualisierungselement (gleicher Look wie Dashboard) zeigt **Trails/Pfade** der gewählten Tags im gewählten Zeitraum
  - Anchors als statische Referenzpunkte einblenden
  - Trail-Linie + Datenpunkte. Hohe Residuals (schlechte Qualität) heller/transparenter zeichnen
- **Zeitleisten-Slider unten:** Scrub durch die Zeit, ein Cursor wandert entlang der Trails
- **Wiedergabe-Steuerung:** Play / Pause / Stop / Geschwindigkeit (1x, 2x, 5x, 10x)
  - Play → Trail-Animation läuft entlang der Zeitleiste
  - Pause → Animation hält an, Cursor bleibt stehen
  - Stop → Animation beendet, Cursor springt zurück an den Anfang
  - Stop beendet **nur die Wiedergabe**, nicht das Backend
- **View-Toggle** identisch zum Dashboard (siehe "Visualisierungselement")
- Datenquelle: `GET /api/positions/{tagId}/history?from=<ts>&to=<ts>` (siehe Backend-Erweiterungen)
- Optional: Datenexport als CSV oder JSON

### 6. Einstellungen (`/settings`)

**Zweck:** System-Konfiguration und Präferenzen.

**Inhalte:**
- Polling-Intervall einstellbar (Live-Dashboard)
- History-Buffer-Größe (Sekunden im Memory)
- Theme (Light/Dark)
- Sprache (de/en)
- WLAN-Info anzeigen (SSID, Passwort als Quick-Reference)
- Liste aktueller API-Endpoints (aus `GET /api`)
- "Setup-Wizard erneut starten" Button
- "Live-Ansicht beenden" als globaler Stop (alternativ zum Toggle in der TopBar)
- "History-Buffer leeren" Button (löscht lokal gepufferte Daten)
- **Kein Server-Shutdown-Button** in der normalen UX. Falls überhaupt vorhanden, dann unter "Erweitert / Admin" mit deutlicher Warnung.

## Visualisierungselement (zentrale Komponente)

Wird auf Dashboard, History, Anchor-Kalibrierung und Setup-Wizard verwendet.

**Aufbau:**
- Rechteckiges Canvas-Element (responsive, behält Aspect-Ratio)
- Boden-Grid (1m-Raster) zur Orientierung
- Achsen-Indikator (Beschriftung passt sich an gewählter Ansicht an)
- Anchors als feste Punkte/Kreise in ihrer konfigurierten Farbe + Label (Name)
- Tags als bewegte Punkte/Kreise in ihrer konfigurierten Farbe + Label
- Trail-Modus (im History-View): Linien-Pfad pro Tag in dessen Farbe
- Bei Live-View und schlechter Qualität (hoher Residual): Tag transparenter / mit gelbem Rand

**View-Toggle (Tab-Leiste am oberen Rand):**

| Modus | Achsen-Mapping | Beschreibung |
|-------|---------------|--------------|
| **Draufsicht (XY)** | horizontal=X, vertikal=Y | Von oben gesehen, Z (Höhe) wird ignoriert |
| **Frontansicht (XZ)** | horizontal=X, vertikal=Z | Von vorn gesehen, Y (Tiefe) wird ignoriert |
| **Seitenansicht (YZ)** | horizontal=Y, vertikal=Z | Von der Seite gesehen, X (Breite) wird ignoriert |
| **3D** (optional, später) | freie Kamera | OrbitControls für Rotation/Zoom |

- Toggle merkt sich User-Wahl pro Seite (LocalStorage)
- Live-Position und Trails verwenden denselben Modus — wechselt der User die Ansicht, ändern sich beide gleichzeitig
- Achsen-Labels und Grid-Beschriftung passen sich automatisch an

**Erste Implementierung:** Draufsicht (XY) — alle anderen Modi sind Achsen-Swaps und damit minimaler Mehraufwand. 3D als letzte Ausbaustufe.

**Empfohlene Library:**
- 2D-Modi: natives Canvas oder [d3](https://d3js.org/) für Skalen/Achsen
- 3D-Modus später: [threlte](https://threlte.xyz/) (Three.js für Svelte)

## Datenmodelle

### Device (vom Backend)

```js
// Device-Objekt vom Backend
{
  id: 'AA:BB:CC:DD:EE:FF',
  type: 'anchor',                     // 'anchor' | 'tag'
  name: 'Anchor-1',
  color: '#00FF00',
  position: { x: 0, y: 0, z: 2.5 },
  lastSeen: 1710765432000,            // ms seit Epoch
  status: 'online'                    // 'online' | 'delayed' | 'offline'
}
```

### TagPosition (vom Backend)

```js
{
  tagId: '11:22:33:44:55:66',
  position: { x: 1.23, y: 2.45, z: 0 },
  timestamp: 1710765432000,
  residual: 0.05
}
```

### HistoryEntry (Frontend-intern)

```js
// pro Tag ein Array dieser Einträge im Frontend-Buffer
{
  timestamp: 1710765432000,
  position: { x: 1.23, y: 2.45, z: 0 },
  residual: 0.05
}
```

JSDoc-Annotationen kannst du im Code verwenden, falls du IDE-Hilfe willst:

```js
/**
 * @typedef {Object} Device
 * @property {string} id
 * @property {'anchor' | 'tag'} type
 * @property {string} name
 * @property {string} color
 * @property {{x:number,y:number,z:number}} position
 * @property {number} lastSeen
 * @property {'online'|'delayed'|'offline'} status
 */
```

## Backend-API-Übersicht

Server: `http://uwbp:8080` (oder `http://10.42.0.1:8080`)

### Bereits implementiert

```
GET  /api/health                    → {"status":"ok"}
GET  /api                           → Liste aller Endpoints
POST /api/devices/register          → ESP32 Self-Registration (Frontend nutzt nicht)
GET  /api/devices                   → {"devices":[Device,...]}
GET  /api/devices/{id}              → Device
PUT  /api/devices/{id}              → Body: {"name":"...","color":"#FF0000"} → Device
GET  /api/anchors                   → {"anchors":[Device,...]}
PUT  /api/anchors/{id}/position     → Body: {"x":0,"y":0,"z":0} → Device
GET  /api/tags                      → {"tags":[Device,...]}
POST /api/ranging                   → Anchor postet Ranging-Daten (Frontend nutzt nicht)
GET  /api/positions                 → {"positions":[TagPosition,...]}
GET  /api/positions/{tagId}         → TagPosition
POST /api/shutdown                  → Server runterfahren (NICHT für Live-Stop verwenden)
```

### Backend-Erweiterungen (für Frontend nötig)

```
GET  /api/devices  → Device-JSON erweitert um:
                    "lastSeen": 1710765432000,
                    "status": "online" | "delayed" | "offline"

GET    /api/positions/{tagId}/history?from=<ms>&to=<ms>
       → {"history":[TagPosition,...]}

DELETE /api/devices/{id}
       → {"ok":true} oder {"error":"..."}

GET    /api/system/info
       → {"uptime":..., "wifi":{...}, "version":"..."}
```

**Optional zukünftig (noch nicht im Backend implementiert):**

```
GET    /api/stream/positions   (Server-Sent Events)
       → stream: data: {TagPosition}\n\n
```

Solange das nicht da ist → klassisches Polling.

**CORS:** Backend muss CORS-Header senden:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type
```

## UX-Anforderungen

- **Keine Login-Funktion**: System läuft im geschlossenen Netzwerk
- **Mobile-tauglich**: Smartphones werden auch genutzt
- **Loading/Error-States überall klar**:
  - Server nicht erreichbar → "Verbindung zum Pi verloren, prüfe WLAN-Verbindung"
  - Keine Anchors registriert → "Schalte mindestens 3 Anchors ein"
  - Anchors haben keine Position → "Konfiguriere die Anchor-Positionen unter /anchors"
  - Anzahl Anchors < 3 → "Brauche mindestens 3 Anchors für Trilateration"
- **Residual-Visualisierung**: schlechte Messqualität (z.B. residual > 0.5m) erkennbar
- **Farben überall konsistent**: Device-Color aus Backend in allen Views
- **Auto-Refresh statt manueller Reload**
- **Status-Indikator immer sichtbar** auf jeder Seite mit Devices
- **Relative Zeitangaben** ("vor 2s", "vor 1min"), automatisch aktualisierend

---

# Style & Code Guide

## Design-Philosophie

- **Tech-Aesthetic**: Dunkler Hintergrund als Default, klare Typografie, viel Whitespace, subtile Akzentfarben
- **Datendichte mit Klarheit**: Live-Werte sofort lesbar
- **Komponenten zuerst**: Eigene Komponenten bauen statt Markup duplizieren
- **Konsistenz vor Kreativität**: Buttons, Karten, Statusfarben überall identisch
- **Mobile-tauglich**: Alles funktioniert ab 360px Breite

## Styling-Ansatz (kein Tailwind!)

- **Globale CSS-Variablen** in `src/app.css` als Design-Tokens (Farben, Spacing, Radii, Fonts)
- **Svelte-scoped `<style>`-Blöcke** in jeder Komponente — Styles sind automatisch isoliert
- **Globale Utility-Klassen** für häufige Layout-Patterns nur wenn wirklich nötig (z.B. `.row`, `.col`, `.card`)
- Keine Inline-Styles außer für dynamische Werte (Position, Backend-Color)

```svelte
<script>
  // ---- props ----
  let { device } = $props();
</script>

<div class="card">
  <span class="dot" class:online={device.status === 'online'}></span>
  {device.name}
</div>

<style>
  .card {
    background: var(--bg-secondary);
    padding: var(--space-4);
    border-radius: var(--radius-md);
  }

  .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--text-muted);
  }

  .dot.online {
    background: var(--status-online);
  }
</style>
```

## Farb-Palette (CSS-Variablen in `src/app.css`)

```css
:root {
  /* ---- backgrounds ---- */
  --bg-primary:    #0B0F14;
  --bg-secondary:  #131922;
  --bg-tertiary:   #1B2330;
  --border:        #2A3444;
  --border-strong: #3D4A5E;

  /* ---- text ---- */
  --text-primary:   #E6EDF3;
  --text-secondary: #9BA9B8;
  --text-muted:     #5C6877;

  /* ---- accent ---- */
  --accent:        #4F8EFF;
  --accent-hover:  #6BA0FF;
  --accent-glow:   #4F8EFF33;

  /* ---- status ---- */
  --status-online:  #34D399;
  --status-delayed: #FBBF24;
  --status-offline: #EF4444;

  /* ---- quality ---- */
  --quality-good:   #34D399;
  --quality-ok:     #FBBF24;
  --quality-bad:    #EF4444;

  /* ---- spacing (4er-schritte) ---- */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-6: 24px;
  --space-8: 32px;
  --space-12: 48px;
  --space-16: 64px;

  /* ---- radii ---- */
  --radius-sm: 4px;
  --radius-md: 6px;
  --radius-lg: 8px;
  --radius-full: 999px;

  /* ---- fonts ---- */
  --font-sans: 'Inter', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;
}

[data-theme='light'] {
  --bg-primary: #FFFFFF;
  /* ... usw. für Light-Theme */
}
```

Light-Theme als Sekundär-Variante, Toggle in den Settings. Dunkel ist Default.

## Typografie

- **Font**: `Inter` (UI), `JetBrains Mono` (für IDs, Koordinaten, Timestamps)
- **Skala** (in CSS-Variablen):
  - `--text-xs`: 12px (Tags, Hints, relative Zeiten)
  - `--text-sm`: 14px (Standard-Body, Tabellen)
  - `--text-base`: 16px (Hervorhebung)
  - `--text-lg`: 18px (Sektion-Headlines)
  - `--text-2xl`: 24px (Seiten-Titel)

## Spacing & Layout

- **Konsequent 4er-Schritte** über `--space-*` Variablen
- **Karten-Padding**: `var(--space-4)` mobile, `var(--space-6)` desktop
- **Sektion-Abstände**: `var(--space-6)` zwischen Karten, `var(--space-4)` innerhalb
- **Maximale Inhaltsbreite**: 1280px zentriert
- **Border-Radius**: `--radius-md` Standard, `--radius-lg` für Karten, `--radius-full` für Status-Dots

## Komponenten-Bibliothek

```
src/lib/components/
├── ui/
│   ├── Button.svelte
│   ├── Card.svelte
│   ├── Input.svelte
│   ├── Select.svelte
│   ├── Slider.svelte
│   ├── Tabs.svelte
│   ├── Badge.svelte
│   ├── Tooltip.svelte
│   ├── Modal.svelte
│   ├── ConfirmDialog.svelte
│   ├── ColorPicker.svelte
│   └── Toast.svelte
├── status/
│   ├── StatusDot.svelte
│   ├── LastSeen.svelte
│   ├── HealthIndicator.svelte
│   ├── QualityBadge.svelte
│   └── RunStateToggle.svelte
├── device/
│   ├── DeviceCard.svelte
│   ├── DeviceList.svelte
│   ├── DeviceRow.svelte
│   ├── PositionInput.svelte
│   └── DeviceColorDot.svelte
├── viz/
│   ├── RoomCanvas.svelte
│   ├── ViewToggle.svelte
│   ├── GridLayer.svelte
│   ├── AxisLabels.svelte
│   ├── AnchorMarker.svelte
│   ├── TagMarker.svelte
│   └── TrailLine.svelte
├── layout/
│   ├── AppShell.svelte
│   ├── Sidebar.svelte
│   ├── TopBar.svelte
│   └── PageHeader.svelte
└── wizard/
    ├── WizardShell.svelte
    ├── WizardStep.svelte
    └── ProgressBar.svelte
```

**Regel:** Wenn dasselbe Markup mehr als 2x verwendet würde → Komponente.

## Svelte 5 Runes — Konventionen

### State

```svelte
<script>
  let count = $state(0);
  let devices = $state([]);
</script>
```

### Derived

```svelte
<script>
  let onlineCount = $derived(devices.filter(d => d.status === 'online').length);
</script>
```

### Effects

```svelte
<script>
  $effect(() => {
    const interval = setInterval(fetchPositions, 150);
    return () => clearInterval(interval);
  });
</script>
```

### Props

```svelte
<script>
  let { device, onSelect } = $props();
</script>
```

### Bindable Props

```svelte
<script>
  let { value = $bindable(0) } = $props();
</script>
```

### Snippets

```svelte
<script>
  let { children, header } = $props();
</script>

<div class="card">
  {#if header}{@render header()}{/if}
  {@render children()}
</div>
```

## State-Management

**Strikte Regel: nur `.svelte` Dateien.** Keine `.svelte.js` / `.svelte.ts` Module. Globaler State lebt im Root-`+layout.svelte` und wird per **Svelte Context API** an alle Child-Komponenten weitergegeben.

### Globaler State im Root-Layout

```svelte
<!-- src/routes/+layout.svelte -->
<script>
  import { setContext } from 'svelte';

  // ---- devices state ----
  let devices = $state([]);
  let devicesLoading = $state(false);

  async function fetchDevices() {
    devicesLoading = true;
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/api/devices`);
      devices = (await res.json()).devices;
    } finally {
      devicesLoading = false;
    }
  }

  // ---- positions state ----
  let positions = $state([]);

  async function fetchPositions() {
    const res = await fetch(`${import.meta.env.VITE_API_URL}/api/positions`);
    positions = (await res.json()).positions;
  }

  // ---- run state ----
  let isRunning = $state(true);

  // ---- effects ----
  $effect(() => {
    if (!isRunning) return;
    const interval = setInterval(fetchPositions, 150);
    return () => clearInterval(interval);
  });

  $effect(() => {
    const interval = setInterval(fetchDevices, 2000);
    return () => clearInterval(interval);
  });

  // ---- context ----
  setContext('app', {
    get devices() { return devices; },
    get devicesLoading() { return devicesLoading; },
    get anchors() { return devices.filter(d => d.type === 'anchor'); },
    get tags() { return devices.filter(d => d.type === 'tag'); },
    get positions() { return positions; },
    get isRunning() { return isRunning; },
    toggleRun: () => { isRunning = !isRunning; },
    startRun:  () => { isRunning = true; },
    stopRun:   () => { isRunning = false; },
    refetchDevices: fetchDevices
  });

  let { children } = $props();
</script>

{@render children()}
```

**Wichtig:** Getter-Properties (`get devices() { return devices; }`) im Context-Objekt sind nötig, damit Reaktivität in den Child-Komponenten funktioniert. Direktes `devices: devices` würde nur den initialen Snapshot weitergeben.

### Zugriff in Child-Komponenten

```svelte
<!-- src/routes/devices/+page.svelte -->
<script>
  import { getContext } from 'svelte';
  import DeviceList from '$lib/components/device/DeviceList.svelte';

  // ---- context ----
  const app = getContext('app');
</script>

<DeviceList devices={app.devices} loading={app.devicesLoading} />
```

```svelte
<!-- src/lib/components/status/RunStateToggle.svelte -->
<script>
  import { getContext } from 'svelte';
  const app = getContext('app');
</script>

<button class="toggle" class:running={app.isRunning} onclick={app.toggleRun}>
  <span class="dot"></span>
  {app.isRunning ? 'Läuft' : 'Gestoppt'}
</button>
```

### Bereiche aufteilen mit Sub-Layouts

Wenn das Root-Layout zu groß wird, kannst du Sub-Layouts wie `src/routes/(app)/+layout.svelte` nutzen und dort weitere Contexts setzen — alles bleibt in `.svelte` Dateien.

### Wiederverwendbare Logik via Komponenten

Falls du logikartige Bausteine wiederverwenden willst (z.B. ein Polling-Hook), pack sie in eine **headless Komponente** ohne Markup:

```svelte
<!-- src/lib/components/util/Poller.svelte -->
<script>
  // ---- props ----
  let { intervalMs, onTick, enabled = true } = $props();

  // ---- effects ----
  $effect(() => {
    if (!enabled) return;
    const id = setInterval(onTick, intervalMs);
    return () => clearInterval(id);
  });
</script>
```

Verwendung:

```svelte
<Poller intervalMs={150} enabled={app.isRunning} onTick={fetchPositions} />
```

## Datei-Struktur

**Strikte Regel: nur `.svelte` Dateien (außer `app.css` und Konfig).** Kein `lib/api/`, `lib/stores/`, `lib/utils/` mit JS-Modulen. State und Logik leben in `.svelte` Komponenten — entweder im Root-Layout oder in headless Util-Komponenten.

```
src/
├── routes/
│   ├── +layout.svelte           # globaler state via Context API
│   ├── +page.svelte             # /  Dashboard
│   ├── setup/+page.svelte
│   ├── devices/+page.svelte
│   ├── anchors/+page.svelte
│   ├── history/+page.svelte
│   └── settings/+page.svelte
├── lib/
│   └── components/
│       ├── ui/
│       ├── status/
│       ├── device/
│       ├── viz/
│       ├── layout/
│       ├── wizard/
│       └── util/                # headless logic-only komponenten (Poller, Fetcher, etc.)
└── app.css                      # einzige nicht-.svelte datei mit logik-relevanz
```

**Konstanten / Konfig:**
Werte aus `import.meta.env.VITE_*` direkt in den Komponenten lesen die sie brauchen. Wenn ein zentraler Ort nötig ist → `+layout.svelte` und via Context weitergeben.

**API-Calls:**
Direkt in den Komponenten bzw. im Layout. Keine separate `client.js`. Wenn das Repetition wird, abstrahier es in eine `<ApiClient>` Util-Komponente die fetch-Funktionen über Context bereitstellt.

## Animation & Motion

- Subtile Übergänge: `transition: all 150ms ease` als Default
- Svelte-Transitions (`fade`, `slide`, `fly`) aus `svelte/transition` für Mount/Unmount
- Keine springenden Layouts — Höhen reservieren auch wenn Inhalt fehlt
- Status-Dot-Pulsieren nur für **Online**-Status
- Tag-Bewegung im Live-View leicht interpoliert (CSS-Transition auf transform 100ms)

```css
.status-dot.online {
  box-shadow: 0 0 0 0 var(--status-online);
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0% { box-shadow: 0 0 0 0 rgba(52, 211, 153, 0.5); }
  70% { box-shadow: 0 0 0 6px rgba(52, 211, 153, 0); }
}
```

## Visualisierungselement (Look)

- Hintergrund: leicht heller als Page-BG, eigene Karte
- Grid-Linien: `var(--border)` mit niedriger Opacity, Hauptachsen kräftiger
- Anchors als gefüllte Kreise mit Border in Device-Color
- Tags als gefüllte Kreise mit Glow-Effekt in Device-Color
- Trail-Linien: dünne Linie (1.5px) in Device-Color, Opacity nach Alter abfallend (neue 100%, alte 30%)
- Achsen-Beschriftung: `var(--font-mono)`, `var(--text-xs)`, `var(--text-muted)`
- Hover: Tooltip mit Device-Name + Position

## Naming-Konventionen

- **Komponenten-Dateien**: PascalCase (`DeviceCard.svelte`)
- **Headless-Util-Komponenten**: PascalCase (`Poller.svelte`, `ApiClient.svelte`)
- **Variablen**: camelCase
- **Konstanten**: UPPER_SNAKE_CASE
- **CSS-Klassen**: kebab-case
- **Boolean-Props**: `is`-, `has`-, `should`-Prefix
- **Event-Handler-Props**: `on`-Prefix (`onSelect`, `onChange`)

## Code-Sprache & Kommentare

- **Variablennamen, Funktionen, Komponenten**: Englisch
- **Code-Kommentare**: Englisch
- **UI-Texte (User-facing)**: Deutsch
- **Commit-Messages**: Englisch

### Kommentar-Regeln

- **Keine erklärenden Kommentare im Code.** Code muss durch gute Namen selbsterklärend sein.
- **Keine JSDoc-Funktionsbeschreibungen** (JSDoc nur für Type-Hints erlaubt, nicht für Erklärungen).
- **Erlaubt sind nur Layout-/Section-Kommentare:**

```javascript
// ---- state ----
let devices = $state([]);
let loading = $state(false);

// ---- actions ----
async function fetchDevices() { }
async function updateDevice(id) { }

// ---- effects ----
$effect(() => { });
```

```svelte
<script>
  // ---- props ----
  let { device, onSelect } = $props();

  // ---- derived ----
  let isOnline = $derived(device.status === 'online');
</script>

<!-- ---- header ---- -->
<div class="header">
</div>

<!-- ---- body ---- -->
<div class="body">
</div>
```

### Verboten

```javascript
// fetches all devices from the api
async function fetchDevices() { }

/**
 * Fetches a single device by id.
 * @param id - the device id
 */
async function getDevice(id) { }
```

### Naming statt Kommentare

```javascript
const ageMs = Date.now() - device.lastSeen;

const isLowQuality = residual > 0.5;
if (isLowQuality) { }
```

### Ausnahme

Nur in absoluten Notfällen — und nur für **Warum**, niemals **Was**:

```javascript
// upstream sends timestamps as float; cast to int to avoid precision drift
const ts = Math.floor(raw.timestamp);
```

## API-Client-Pattern

Da nur `.svelte` Dateien erlaubt sind, lebt der API-Client als **headless Komponente** im Layout. Sie stellt fetch-Funktionen über Context bereit, niemals inline `fetch()` in Page-Komponenten.

```svelte
<!-- src/lib/components/util/ApiClient.svelte -->
<script>
  import { setContext } from 'svelte';

  // ---- props ----
  let { children } = $props();

  // ---- config ----
  const BASE = import.meta.env.VITE_API_URL;

  // ---- core ----
  async function request(path, init) {
    const res = await fetch(`${BASE}${path}`, {
      ...init,
      headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) }
    });
    if (!res.ok) throw new Error(`API ${res.status}: ${await res.text()}`);
    return res.json();
  }

  // ---- devices ----
  const devices = {
    list:   ()         => request('/api/devices'),
    get:    (id)       => request(`/api/devices/${id}`),
    update: (id, data) => request(`/api/devices/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
    remove: (id)       => request(`/api/devices/${id}`, { method: 'DELETE' })
  };

  // ---- anchors ----
  const anchors = {
    list:        ()             => request('/api/anchors'),
    setPosition: (id, x, y, z)  => request(`/api/anchors/${id}/position`, {
      method: 'PUT',
      body: JSON.stringify({ x, y, z })
    })
  };

  // ---- positions ----
  const positions = {
    all:     ()                  => request('/api/positions'),
    one:     (id)                => request(`/api/positions/${id}`),
    history: (id, fromMs, toMs)  => request(`/api/positions/${id}/history?from=${fromMs}&to=${toMs}`)
  };

  // ---- system ----
  const system = {
    health:   () => request('/api/health'),
    routes:   () => request('/api'),
    shutdown: () => request('/api/shutdown', { method: 'POST' })
  };

  setContext('api', { request, devices, anchors, positions, system });
</script>

{@render children()}
```

Verwendung im Root-Layout:

```svelte
<!-- src/routes/+layout.svelte -->
<script>
  import ApiClient from '$lib/components/util/ApiClient.svelte';
  let { children } = $props();
</script>

<ApiClient>
  {@render children()}
</ApiClient>
```

Zugriff in Page-Komponenten:

```svelte
<script>
  import { getContext } from 'svelte';
  const api = getContext('api');

  let devices = $state([]);

  async function load() {
    devices = (await api.devices.list()).devices;
  }
</script>
```

## Accessibility

- Semantisches HTML (`<button>`, `<nav>`, `<main>`)
- ARIA-Labels für Icon-only-Buttons
- Keyboard-Navigation überall (Tab, Enter, Escape)
- Fokus-Indikatoren sichtbar (`:focus-visible { outline: 2px solid var(--accent); }`)
- Farbe nie alleiniger Indikator (Status-Dot zusätzlich Text/Icon)

## Code-Qualität

- **Prettier** + **ESLint** mit `eslint-plugin-svelte`
- Komponenten unter 200 Zeilen
- Logik aus Komponenten in Utils oder Stores auslagern
- Keine ungenutzten Imports oder Variablen

## Implementierungs-Reihenfolge

1. **Setup**: SvelteKit-Projekt anlegen (`npx sv create`), API-Client schreiben, Routing
2. **Geräte-Verwaltung** (`/devices`): einfachste Seite mit Alive-Ansicht und Status-Farben
3. **Anchor-Kalibrierung** (`/anchors`): Eingabe-Forms + simple 2D-Vorschau (Draufsicht)
4. **Visualisierungselement** als wiederverwendbare Komponente (Draufsicht zuerst)
5. **Setup-Wizard** (`/setup`): nutzt Komponenten aus 2-4
6. **Live-Dashboard** (`/`) mit Sidebar (Alive-Ansicht), Run-State-Toggle und Visualisierungselement
7. **History** (`/history`): Datenabruf + Trail-Rendering + Wiedergabe-Steuerung
8. **View-Toggle erweitern**: Front- und Seitenansicht
9. **Settings** (`/settings`)
10. **3D-Ansicht** als optionale Erweiterung mit threlte

## Empfohlene Libraries

| Zweck | Empfehlung |
|-------|------------|
| 3D-Rendering (optional) | [threlte](https://threlte.xyz/) |
| 2D-Canvas | natives Canvas oder [d3](https://d3js.org/) |
| Charts/Zeitleiste | [Chart.js](https://www.chartjs.org/) oder [d3](https://d3js.org/) |
| Color-Picker | natives `<input type="color">` |
| Datepicker | selbst gebaut oder z.B. `flatpickr` |
| Icons | [lucide-svelte](https://lucide.dev/) |
| Relative Time | [dayjs](https://day.js.org/) mit `relativeTime`-Plugin |

## Frontend-Konfiguration

```env
VITE_API_URL=http://uwbp:8080
VITE_POLL_INTERVAL_POSITIONS=150
VITE_POLL_INTERVAL_DEVICES=2000
VITE_HISTORY_BUFFER_SECONDS=600
VITE_STATUS_ONLINE_THRESHOLD_MS=5000
VITE_STATUS_DELAYED_THRESHOLD_MS=30000
```

## Setup auf dem Pi (Deployment)

```bash
cd /home/pi
git clone <frontend-repo> uwbp_frontend
cd uwbp_frontend
npm install

git pull
npm install
npm run build

node build   # läuft auf PORT (env-var, default 3000)
```

**systemd-Service ist nicht zwingend** — du kannst das Frontend auch einfach manuell mit `node build` starten. Wenn du Auto-Start beim Boot willst, kannst du nachträglich eine `.service`-Datei dafür anlegen, das ist aber ein separater Schritt und nicht Teil des Frontend-Setups.

## Architektur-Diagramm

```
[User-Browser] ──http://uwbp──> Port 80 ──redirect──> Port 3000 [SvelteKit]
                                                          │
                                                          │ fetch
                                                          ▼
                                                  Port 8080 [C++ Backend]
                                                          │
                                                          │ D-Bus
                                                          ▼
                                                  [NetworkManager / WLAN UWBP]
                                                          ▲
                                                          │ HTTP REST
                                  ┌───────────────────────┼───────────────────────┐
                              [ESP32 Anchor 1] [ESP32 Anchor 2] [ESP32 Tag 1] ...
```

## Beenden des Systems

**Wichtig:** Im Frontend gibt es zwei verschiedene "Beenden"-Aktionen:

1. **Live-Ansicht beenden** (Run-State-Toggle, Wiedergabe-Stop)
   - Stoppt nur die Visualisierung im Frontend
   - Backend läuft weiter und sammelt weiter Daten
   - User kann jederzeit "Starten" und sieht wieder Live-Daten

2. **Backend beenden** (`POST /api/shutdown`)
   - Versteckte Admin-Funktion, **nicht** als normaler Stop-Button
   - Beendet den C++ Server auf dem Pi
   - WLAN bricht ab, Pi muss manuell neu gestartet werden

User-Optionen das gesamte System zu beenden:
1. Frontend → Settings → "Erweitert" → "Server beenden" (mit Confirm-Dialog)
2. SSH auf den Pi und `Ctrl+C` im laufenden `make run`
3. Pi-Stromstecker ziehen

## Die 5 Regeln

1. **Svelte 5 Runes Mode** überall, keine alten Stores
2. **Eigene Komponenten** statt copy-paste, alles unter `src/lib/components/`
3. **Pures CSS mit CSS-Variablen** für Theming, kein Framework, keine Inline-Styles
4. **Konsistente Status-Farben und Spacing** — Design-Tokens zentral in `app.css`
5. **Tech-Aesthetic, dunkel, datendicht, klar** — kein Bloat, keine Ornamente
