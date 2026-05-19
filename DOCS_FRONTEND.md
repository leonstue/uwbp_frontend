# Projektdokumentation — UWBP Frontend

> **Hinweis für die LaTeX-erzeugende KI**: Dieses Dokument beschreibt **ausschließlich das Frontend-Teilprojekt** des UWBP-Systems. Es gibt zwei weitere, separate Teilprojekte (`uwbp_server` für das C++-Backend auf dem Raspberry Pi sowie `uwbp_anchor` für die ESP32-Firmware), die hier **nicht** im Detail dokumentiert werden. Sofern in der finalen LaTeX-Doku Querverweise auf Backend oder Firmware nötig sind, bitte als Verweis auf die jeweiligen Repositories belassen, nicht inhaltlich vermischen.

---

## 1. Projektidentifikation

| Feld | Wert |
|---|---|
| **Teilprojekt** | UWBP Frontend |
| **Repository** | `https://github.com/leonstue/uwbp_frontend` |
| **Schwesterrepos** | `uwbp_server` (C++ Backend), `uwbp_anchor` (ESP32-Firmware) |
| **Sprache** | JavaScript (kein TypeScript), UI-Texte deutsch, Code englisch |
| **Build-System** | Vite + SvelteKit |
| **Laufzeit** | Node.js (`@sveltejs/adapter-node`) als systemd-Service auf einem Raspberry Pi 5 |
| **Hauptbenutzer** | Endnutzer im selben WLAN wie der Pi (Browser auf PC oder Smartphone) |

---

## 2. Projektkontext und Gesamtarchitektur

UWBP („UWB Positioning") ist ein **Indoor-Positioning-System auf Basis von Ultra-Wideband-Funk**. Die Hardware besteht aus:

- **Mehreren ESP32-Anchors**, die fest im Raum montiert werden und als ortsfeste UWB-Bake fungieren.
- **Einem oder mehreren ESP32-Tags**, die bewegbar sind und deren Position im Raum live ermittelt wird.
- **Einem Raspberry Pi 5**, der einen eigenen WiFi-Access-Point („UWBP", Passwort `abcd1234`) aufspannt und sowohl die ESP32-Devices als auch das User-Endgerät verbindet. Der Pi ist über den DNS-Alias `uwbp` bzw. die statische IP `10.42.0.1` erreichbar.

Auf dem Pi laufen zwei Prozesse:

1. **C++-Backend (`uwbp_server`)** auf Port 8080, sammelt Ranging-Messwerte der Anchors, trianguliert die Tag-Positionen und stellt die Ergebnisse als REST-API bereit.
2. **SvelteKit-Frontend (dieses Teilprojekt)** auf Port 80, das den User-Browser mit dem Dashboard, der Konfigurationsoberfläche und der Visualisierung versorgt.

Schematisch:

```
[Browser]──http://uwbp──▶[Pi:80, Frontend (Node.js)]──fetch──▶[Pi:8080, C++ Backend]──Ranging──▶[ESP32-Anchors/Tags]
```

Das Frontend ist also **die einzige Schnittstelle zwischen Mensch und System**: Konfiguration, Live-Visualisierung und Auswertung. Es kommuniziert mit dem Backend ausschließlich über HTTP-REST.

---

## 3. Intention und Zielsetzung

Das Frontend wurde gebaut, um die folgenden Ziele zu erfüllen:

1. **Erstkonfiguration ohne Spezialwissen**: Ein End-User soll nach dem Einschalten des Systems über einen geführten Wizard alle Anchors und Tags benennen, einfärben und positionieren können, ohne JSON-Dateien oder Kommandozeile.
2. **Live-Visualisierung mit niedriger Latenz**: Die aktuellen Tag-Positionen werden mit Polling-Intervallen unter 100 ms abgefragt und im Browser interpoliert dargestellt — visuell flüssig statt sprunghaft.
3. **Räumliches Verständnis**: Sowohl 2D-Projektionen (Draufsicht, Front, Seite) als auch eine 3D-Ansicht mit OrbitControls erlauben dem Nutzer, die Position von Anchors und Tags in beliebiger Perspektive zu erfassen.
4. **Historische Analyse**: Bewegungs-Trails über frei wählbare Zeitfenster, mit Wiedergabe-Steuerung (Play/Pause/Stop, variable Geschwindigkeit) und einer farbcodierten Aktivitäts-Bar pro Tag, die die zeitliche Verteilung der Bewegung sichtbar macht.
5. **Robustheit gegen Backend-/Netzwerk-Aussetzer**: Auch wenn das Backend langsam antwortet oder kurzzeitig nicht erreichbar ist, sollen sich keine Request-Stapel aufbauen, die das System weiter destabilisieren.
6. **Demo-taugliche Bedienbarkeit**: Im laufenden Betrieb deploybar (Staging-Verfahren), ohne dass eine Live-Demo durch einen Frontend-Restart unterbrochen wird.
7. **Gerätekuratierung**: Nur Devices, die der Nutzer aktiv im Wizard durchlaufen hat, werden im Dashboard angezeigt — ein einfaches Approval-Gate gegen unbeabsichtigt registrierte Fremdgeräte.

---

## 4. Funktionsumfang

### 4.1 Seiten / Routes

| Route | Zweck |
|---|---|
| `/` | **Dashboard** — Live-Visualisierung, Geräte-Liste mit Status, Toggle für Trail-Anzeige, View-Toggle 2D/3D |
| `/starten` | **Wizard** — siebenstufiger Onboarding-Prozess zur Erstkonfiguration |
| `/devices` | **Geräte-Verwaltung** — Tabelle/Karten aller approved Devices mit Inline-Edit für Name und Farbe, Vergessen-Funktion |
| `/anchors` | **Anchor-Kalibrierung** — pro Anchor x/y/z-Eingabe in Metern, Live-Vorschau im Canvas, Vorlagen für Rechteck/Dreieck-Layouts, Duplikat-Warnung |
| `/history` | **Historie** — Multi-Select Tags, Zeitraum-Auswahl (1m/5m/15m/1h/Custom mit Flatpickr), progressive Trail-Animation bis zur Cursor-Zeit, Aktivitäts-Bar pro Tag, CSV-/JSON-Export |
| `/settings` | **Einstellungen** — Polling-Intervalle, History-Buffer, Theme, Netzwerk-Info, API-Endpoint-Liste, Wizard erneut öffnen, Geräte-Freigabe zurücksetzen, Server-Shutdown unter „Erweitert" |

### 4.2 Wizard-Flow (Onboarding)

Der Wizard unter `/starten` führt durch sieben Schritte:

1. **Willkommen** — Erklärung der nächsten Schritte.
2. **Anchors einschalten** — Live-Counter der eingehenden Anchor-Registrierungen mit Mindestschwelle von drei.
3. **Anchors benennen** — Name + Farbe pro Anchor (PUT `/api/devices/{id}`).
4. **Anchor-Positionen** — x/y/z-Eingabe pro Anchor mit Live-Preview (PUT `/api/anchors/{id}/position`), Vorlagen-Modal für gängige Raum-Layouts.
5. **Tags einschalten** — analog zu Schritt 2 mit Mindestschwelle von einem Tag.
6. **Tags benennen** — analog zu Schritt 3.
7. **Fertig** — beim Klick auf „Zum Dashboard" werden alle aktuell sichtbaren Devices in die approval-Liste aufgenommen (`localStorage.uwbp.approvedDevices`).

Während der gesamten Wizard-Phase werden alle ankommenden Devices ohne Approval-Filter angezeigt (`rawDevices`/`rawAnchors`/`rawTags`-Getter im Context). Erst beim Wizard-Abschluss wird der aktuelle Stand „eingefroren".

### 4.3 Visualisierungselement (`RoomCanvas.svelte`)

Wird auf Dashboard, Anchor-Kalibrierung, Wizard und Historie wiederverwendet. Unterstützt vier Modi:

| Modus | Achsen-Mapping (horizontal/vertikal) | Beschreibung |
|---|---|---|
| **Draufsicht (XY)** | X / Y | Standardmodus, Z (Höhe) ignoriert |
| **Frontansicht (XZ)** | X / Z | Y (Tiefe) ignoriert |
| **Seitenansicht (YZ)** | Y / Z | X (Breite) ignoriert |
| **3D** | freie Kamera | OrbitControls (Maus-Drag rotieren, Scrollwheel zoomen) |

In allen 2D-Modi werden:
- Boden-Grid mit 1 m-Raster gezeichnet,
- Achsen beschriftet (mit JetBrains Mono),
- Anchors als gefüllte Kreise mit Border in Device-Color dargestellt,
- Tags als gefüllte Kreise mit Glow-Effekt und Quality-Indikator (transparenter und mit gelbem Rand bei Residual > 0.5 m),
- optionale Trails als dünne, in Helligkeit/Stärke nach Geschwindigkeit modulierte Linien,
- Hover-Tooltips mit Device-Name und Position eingeblendet.

Im 3D-Modus werden Anchors als Würfel (BoxGeometry), Tags als leuchtende Kugeln mit zusätzlichem PointLight, Boden als `THREE.GridHelper` und Achsen als `THREE.AxesHelper` (rot/grün/blau für X/Y/Z) gerendert. Threlte (Three.js für Svelte) wird **lazy** nachgeladen, der 3D-Code-Chunk landet nicht im Initial-Bundle.

### 4.4 Live-Daten-Pipeline

- Drei Poller laufen zentral in `AppState.svelte`, nicht in einzelnen Pages: `GET /api/devices` (alle ~2000 ms), `GET /api/positions` (alle ~80 ms), `GET /api/health` (alle 5000 ms).
- Polling ist **gegated**: ohne approved Devices und außerhalb des Wizards wird gar nicht gefragt. Damit erzeugt eine frische Installation keinerlei Backend-Last.
- Pro Endpoint **maximal eine Request gleichzeitig** in der Luft (`devicesInFlight`/`positionsInFlight`/`healthInFlight`-Guards). Eine slow-Antwort verhindert nicht das nächste Tick-Intervall — sie verzögert nur die *nächste* Request.
- Jeder Request hat einen **`AbortController`-Timeout** (`VITE_REQUEST_TIMEOUT_MS`, default 1500 ms) — hängende Calls werden gekillt, nicht ewig offen gehalten.
- Nach mehr als drei aufeinanderfolgenden Positions-Fehlern greift ein **Exponential-Backoff** bis 2 s.
- Render-seitig wird die Tag-Position zwischen Polling-Ticks **per RAF-Loop interpoliert** (lerp mit Faktor 0.18), sodass die Bewegung visuell flüssig bleibt, auch wenn die Daten in 80 ms-Schritten kommen.
- Ein lokaler **Live-Buffer** (`tagHistory` Map, default 600 s) puffert die letzten Positionen pro Tag-ID und versorgt sowohl den Dashboard-Trail (3 s) als auch die Cursor-Sprung-Funktion in der Historie.

### 4.5 Trail-Logik

- Distance-Filter mit Schwelle 4 cm im Welt-Koordinatensystem: nur Punkte mit Mindestabstand zum vorherigen werden in den Trail aufgenommen. Ergebnis: bei Stillstand keine neuen Trail-Punkte → der Trail verfällt komplett über die Lifetime.
- Lifetime-Fade: alte Trail-Punkte werden nach hinten transparenter (im 2D als Alpha auf der Linie, im 3D über Vertex-Colors mit `AdditiveBlending`).
- Geschwindigkeits-Modulation: bei langsamer Bewegung wird die 2D-Linie etwas dicker, bei schneller Bewegung dünner.
- In der Historie ist der Trail **progressiv**: er wird nur bis zum aktuellen `cursorTs` gezeichnet, der bewegliche Cursor-Punkt sitzt am Trail-Ende. Während der Wiedergabe wächst der Trail mit dem Cursor mit.

### 4.6 Aktivitäts-Bar in der Historie

Über dem Zeitleisten-Slider zeigt für jeden ausgewählten Tag eine schmale Bar in dessen Farbe **120 Buckets** über die gewählte Range. Pro Bucket: Höhe proportional zur akkumulierten Bewegungsstrecke, Opacity zeigt die reine Anwesenheit. Klick auf einen Bucket springt mit dem Cursor dorthin. Dadurch sind Bewegungs-Hotspots auf einen Blick erkennbar und gezielt anspringbar.

### 4.7 Approval-Gate für Devices

Damit nur kuratierte Devices im normalen Betrieb auftauchen, wird ein **Approval-Set** in `localStorage.uwbp.approvedDevices` gepflegt:

- `app.devices` / `app.anchors` / `app.tags` / `app.positions` sind **gefilterte** Sichten — sie liefern nur Devices aus dem Approval-Set.
- `app.rawDevices` / `app.rawAnchors` / `app.rawTags` / `app.rawPositions` sind die ungefilterten Originale, die nur der Wizard nutzt.
- `app.approveAllCurrent()` (vom Wizard beim „Fertig"-Klick aufgerufen) übernimmt die aktuell sichtbaren Device-IDs ins Set.
- `app.clearApproved()` (Settings-Button „Geräte-Freigabe zurücksetzen") leert das Set wieder.

### 4.8 Visuelle und sprachliche Konventionen

- **Pause-Status der TopBar** unterscheidet drei Fälle:
  - „Läuft" (grün, pulsierender Dot) — Polling aktiv.
  - „Pausiert" (gelb, kein Klick möglich) — kein Setup, weil Approval-Set leer und kein Wizard offen.
  - „Gestoppt" (grau) — Nutzer hat manuell pausiert.
- Erklärende Banner unterhalb der TopBar geben den jeweiligen Grund aus.
- Theme: Dark (Default) und Light, persistiert in `localStorage.uwbp.theme`. Theme-Wechsel triggert über einen `MutationObserver` ein Re-Render des Canvas, sodass auch die Hintergrundfarben der Visualisierung mitlaufen.
- Toggle-Komponente ersetzt native Checkboxen vollständig (im Stil eines iOS-/macOS-Switches mit animiertem Thumb).
- Tagcheck/Geräteauswahl in der Historie erfolgt über die gleiche Toggle-Komponente, der gesamte Listeneintrag (inkl. Color-Dot und Name) ist klickbar dank `<label>`-Wrapper.

---

## 5. Tech-Stack

| Bereich | Wahl | Begründung |
|---|---|---|
| Framework | **Svelte 5** (Runes-Mode `$state`, `$derived`, `$effect`, `$props`, `$bindable`) | Reaktivität ohne Stores-Boilerplate, Compile-Time-Optimierung, schlankes Bundle |
| Routing/SSR | **SvelteKit** mit `adapter-node` | Production-fähiger Node-Server statt Static Build → server-side Hooks für Proxying möglich |
| Build/Dev | **Vite** (von SvelteKit fest eingebaut) | Schnelle Dev-Reloads, eingebauter Proxy für CORS-Vermeidung im Dev-Modus |
| Sprache | JavaScript + JSDoc | Spec-Vorgabe; svelte-check liefert dennoch Type-Inferenz dank `jsconfig.json` |
| Styling | Pures CSS in scoped `<style>`-Blöcken + globale CSS-Variablen in `src/app.css` | Spec-Vorgabe „kein Tailwind", Theme-Switch über Custom-Properties |
| 3D | **Threlte 8** + **Three.js 0.184** (lazy geladen) | Deklarative Three.js-Anbindung passend zum Svelte-Stil |
| 2D | natives `<canvas>` mit eigener Render-Pipeline | Volle Kontrolle, kein Abhängigkeits-Overhead |
| Icons | `lucide-svelte` | Leichtgewichtige, konsistente Icon-Familie |
| Date-Picker | `flatpickr` mit deutscher Lokalisierung | Stabil, gut stylebar |
| Date-Formatter | `dayjs` mit `relativeTime`-Plugin und `de`-Locale | Klein (~7 KB), reicht für „vor 3 s"-Anzeigen |
| Code-Qualität | `prettier`, `prettier-plugin-svelte`, `eslint`, `eslint-plugin-svelte`, `svelte-check` (mit `--tsgo` Flag für die Go-basierte TypeScript-Engine) | `npm run lint` und `npm run check` jeweils mit 0 Errors / 0 Warnings |

---

## 6. Software-Architektur

### 6.1 Layer

Der Code ist als verschachtelte Provider-Hierarchie aufgebaut, alle State-Logik in `<script>`-Blöcken in `.svelte`-Dateien (Spec-Regel: keine `.svelte.js`-Module, eine kontrollierte Ausnahme für `src/hooks.server.js`):

```
+layout.svelte
└── ApiClient.svelte         (setzt Context "api": fetch-Wrapper, Mock-Switch)
    └── AppState.svelte       (setzt Context "app": Devices, Positions, Theme, Approval, Polling)
        └── ToastHost.svelte   (setzt Context "toast": push/dismiss)
            └── AppShell.svelte  (TopBar + Banner + Main-Content-Slot)
                └── {#render children()}  ← die jeweilige Page
```

Damit haben alle Pages über `getContext('app')` / `getContext('api')` / `getContext('toast')` Zugriff auf den globalen State, **ohne** dass eine Library wie Pinia/Redux/Zustand benötigt wird.

### 6.2 State-Modell

In `AppState.svelte`:

- **Datendaten** (`devices`, `positions`, `serverHealth`) — ankommend per Polling, in `$state`.
- **UI-Zustand** (`isRunning`, `theme`, `pollIntervalPositions`, `pollIntervalDevices`, `historyBufferSeconds`) — nutzergesteuert, persistiert in `localStorage`.
- **Approval-Set** (`approvedDeviceIds`, Set von Device-IDs) — vom Wizard befüllt, in `localStorage`.
- **Buffer** (`tagHistory`, Map<tagId, HistoryEntry[]>) — wird bei jedem Positions-Tick befüllt, getrimmt auf `historyBufferSeconds`.
- **Derived**: `pollingActive`, `pauseReason`, `isSetup`, `anchors`, `tags`.

### 6.3 Datenmodelle

Vom Backend gelieferte Strukturen:

```js
// Device
{
  id: 'AA:BB:CC:DD:EE:FF',
  type: 'anchor' | 'tag',
  name: 'Anchor-1',
  color: '#34D399',
  position: { x: 0, y: 0, z: 2.5 },
  lastSeen: 1710765432000,
  status: 'online' | 'delayed' | 'offline'
}

// TagPosition
{
  tagId: '11:22:33:44:55:66',
  position: { x: 1.23, y: 2.45, z: 0 },
  timestamp: 1710765432000,
  residual: 0.05
}
```

Frontend-intern:

```js
// HistoryEntry (Buffer)
{
  timestamp: 1710765432000,
  position: { x: 1.23, y: 2.45, z: 0 },
  residual: 0.05
}
```

### 6.4 API-Client

`ApiClient.svelte` ist die einzige Stelle für fetch-Calls. Schaltlogik:

- `VITE_API_URL` leer → **Mock-Modus**: in-memory Devices und ein Sinus/Cosinus-Generator für Tag-Bewegung; alle Endpoints werden lokal beantwortet.
- `VITE_API_URL` gesetzt (typischerweise `/api`) → **Real-Modus**: relative HTTP-Calls.

Im Real-Modus wird die Base-URL **normalisiert**: trailing `/` und versehentliches `/api` am Ende werden entfernt. Verhindert die häufige Doppelung `/api/api/...`.

Endpoint-Struktur:

```
api.devices.list()/get(id)/update(id, data)/remove(id)
api.anchors.list()/setPosition(id, x, y, z)
api.positions.all()/one(id)/history(id, fromMs, toMs)
api.system.health()/routes()/info()/shutdown()
```

### 6.5 Server-Side-Proxy für CORS-Freiheit

Production läuft das Frontend auf Port 80, das Backend auf Port 8080 — verschiedene Origins, würde jeden fetch zu einem CORS-Preflight machen. Ein Test ergab, dass das Backend keine CORS-Header sendet, alle Preflights canceled wurden, und das System binnen Sekunden in einen scheinbar offline-Zustand kippte.

Lösung: `src/hooks.server.js` proxied alle Pfade die mit `/api` beginnen **server-seitig** an `BACKEND_URL` (default `http://localhost:8080`, weil Frontend und Backend auf demselben Pi laufen). Der Browser sieht nur die eigene Origin, kein CORS, kein Preflight. Im Hook ist ebenfalls ein `AbortController`-Timeout (default 2000 ms) und Console-Error-Logging für Diagnose über `journalctl` enthalten.

Im Dev-Modus übernimmt der **Vite-Proxy** in `vite.config.js` die gleiche Aufgabe (mappt `/api` auf `VITE_BACKEND_URL`).

### 6.6 Polling-Loop ohne Stacking

`Poller.svelte` implementiert die zentrale Loop-Logik:

```js
async function loop() {
  if (immediate) await onTick();
  while (alive) {
    const start = performance.now();
    await onTick();
    const elapsed = performance.now() - start;
    const delay = Math.max(0, intervalMs - elapsed);
    await new Promise(r => setTimeout(r, delay));
  }
}
```

Eine neue Iteration startet **erst nachdem** die vorherige beendet ist. Bei langsamer Antwort verzögert sich nur die nächste Iteration, es entsteht kein paralleles Anhäufen.

### 6.7 Visualisierungs-Pipeline (2D)

`RoomCanvas.svelte` nutzt einen **kontinuierlichen RAF-Loop**:

1. `stepInterpolation()` lerpt pro Tag die aktuelle Display-Position Richtung Ziel mit Faktor 0.18.
2. Wenn sich Display-Positionen verändert haben oder ein Re-Render-Flag gesetzt ist, wird neu gezeichnet.
3. Re-Render-Flags werden gesetzt bei: Resize (ResizeObserver), Theme-Wechsel (MutationObserver auf `data-theme`), Hover-Interaktion, Props-Änderung (`$effect`).

Die Render-Funktion zeichnet sequenziell: Hintergrund → Grid → Achsen → Trails → Anchors → Tags → Hover-Tooltip. Hilfsfunktionen für Grid, Achsenbeschriftung, Anchor-Marker, Tag-Marker und Trail-Linie liegen in eigenen `.svelte`-Dateien mit `<script module>`-Block und exportierten `draw*`-Funktionen — kein Markup, nur Render-Logik. Damit sind sie testbar und wiederverwendbar.

### 6.8 Visualisierungs-Pipeline (3D)

`RoomScene3D.svelte` (Threlte) ist als **lazy import** in `RoomCanvas.svelte` eingebunden — Three.js wird nur geladen, wenn der Nutzer explizit auf die 3D-Ansicht wechselt. Beim Wechsel zurück auf 2D bleibt der Threlte-Modul-Cache bestehen, ein erneutes Wechseln auf 3D ist verzögerungsfrei.

Wichtige Details:
- Initial-Camera-Position wird **einmal** in `onMount` aus den Anchors berechnet und dann eingefroren. OrbitControls darf danach die Kamera frei steuern, ohne dass jeder Polling-Tick die Position auf den Mittelpunkt zurücksetzt.
- World-zu-Three.js-Mapping: `(x, y, z)` → `(x, z, -y)`, weil Three.js die Y-Achse als „Oben" definiert, in unserem Koordinatensystem aber Z der „Oben"-Wert ist.
- Trails als `THREE.Line` mit `BufferGeometry` und Vertex-Colors plus `AdditiveBlending` — leuchtend, ohne separaten Glow-Shader.

---

## 7. Konfiguration

### 7.1 Environment-Variablen

`.env`-Datei im Projektroot bzw. unter `/opt/uwbp/frontend/.env` für die deployte Version:

| Variable | Default | Wirkung |
|---|---|---|
| `VITE_API_URL` | leer | leer = Mock-Modus, `/api` = Real-Modus über Proxy |
| `VITE_BACKEND_URL` | `http://uwbp:8080` | Ziel des Vite-Dev-Proxys |
| `BACKEND_URL` | `http://localhost:8080` | Ziel des Production-Server-Hooks |
| `PROXY_TIMEOUT_MS` | `2000` | Server-Side-Timeout für Backend-Calls |
| `VITE_POLL_INTERVAL_POSITIONS` | `80` | ms, Positions-Polling-Tick |
| `VITE_POLL_INTERVAL_DEVICES` | `2000` | ms, Devices-Polling-Tick |
| `VITE_REQUEST_TIMEOUT_MS` | `1500` | ms, Client-seitiger AbortController-Timeout |
| `VITE_HISTORY_BUFFER_SECONDS` | `600` | s, Größe des Live-Buffers |
| `VITE_STATUS_ONLINE_THRESHOLD_MS` | `1000` | < 1 s seit lastSeen → Online (grün) |
| `VITE_STATUS_DELAYED_THRESHOLD_MS` | `5000` | < 5 s → Verzögert (gelb), darüber Offline (rot) |

### 7.2 Build-/Deployment-Pipeline

Das `Makefile` orchestriert alle Schritte:

| Target | Wirkung |
|---|---|
| `make install-deps` | apt-update, Node.js, npm, `n stable` |
| `make set-live-env` | erstellt `.env` mit `VITE_API_URL=/api`, `VITE_BACKEND_URL`, `BACKEND_URL` |
| `make build` | `npm install && npm run build` |
| `make deploy-artifact` | kopiert `build/`, `package.json`, `node_modules`, `.env` nach `/opt/uwbp/frontend.next` (Staging) |
| `make install-service` | kopiert `deploy/uwbp-frontend.service` nach `/etc/systemd/system/`, `daemon-reload`, `enable` (kein `start`) |
| `make deploy` | Komplett-Pipeline, ohne Service-Restart |
| `make start` / `make stop` | manueller Service-Restart bzw. -Stop |
| `make logs` | letzte 50 Zeilen `journalctl -u uwbp-frontend.service` |
| `make clean` / `make clean-artifacts` | Service deinstallieren bzw. nur Artefakt entfernen |

### 7.3 Staging-Deployment

`make deploy` schreibt **nicht** direkt nach `/opt/uwbp/frontend`, sondern nach `/opt/uwbp/frontend.next`. Ein laufender Service wird dabei nicht angefasst. Beim nächsten Service-Start (Reboot oder `make start`) prüft `ExecStartPre` in der systemd-Service-Datei:

```bash
if [ -d /opt/uwbp/frontend.next ]; then
    rm -rf /opt/uwbp/frontend && mv /opt/uwbp/frontend.next /opt/uwbp/frontend
fi
```

Atomares `mv` auf demselben Filesystem — keine Race-Condition, kein „halb deployt"-Zustand. Demos können während dem laufenden Betrieb ohne Unterbrechung ein neues Build vorbereiten und kontrolliert beim nächsten Reboot aktivieren.

### 7.4 systemd-Unit (`deploy/uwbp-frontend.service`)

```ini
[Unit]
Description=UWBP Frontend Server
Requires=uwbp-server.service
After=uwbp-server.service

[Service]
Type=simple
WorkingDirectory=/opt/uwbp/frontend
ExecStartPre=/bin/bash -c 'if [ -d /opt/uwbp/frontend.next ]; then rm -rf /opt/uwbp/frontend && mv /opt/uwbp/frontend.next /opt/uwbp/frontend; fi'
ExecStart=/usr/local/bin/node build
Restart=always
RestartSec=5
User=root
Environment=HOST=0.0.0.0
Environment=PORT=80
Environment=BACKEND_URL=http://localhost:8080
Environment=PROXY_TIMEOUT_MS=2000
EnvironmentFile=-/opt/uwbp/frontend/.env

[Install]
WantedBy=multi-user.target
```

`User=root` ist nötig, weil Port 80 ein privilegierter Port ist. Alternative wäre `setcap`, wurde der Einfachheit halber nicht verwendet.

---

## 8. Verzeichnisstruktur

```
src/
├── app.css                                # globale Tokens, Reset, Theme
├── app.html                               # Root-HTML, Inter & JetBrains Mono Webfonts
├── hooks.server.js                        # Server-Side /api-Proxy (Production)
├── routes/
│   ├── +layout.svelte                     # Provider-Kette
│   ├── +page.svelte                       # Dashboard
│   ├── starten/+page.svelte               # Wizard
│   ├── devices/+page.svelte               # Geräte-Verwaltung
│   ├── anchors/+page.svelte               # Anchor-Kalibrierung
│   ├── history/+page.svelte               # Historie
│   └── settings/+page.svelte              # Einstellungen
└── lib/
    └── components/
        ├── ui/                            # Button, Card, Input, Select, Slider, Tabs,
        │                                  # Badge, Tooltip, Modal, ConfirmDialog,
        │                                  # ColorPicker, Toast, ToastHost, ThemeToggle,
        │                                  # Toggle, DateRangePicker
        ├── status/                        # StatusDot, LastSeen, HealthIndicator,
        │                                  # QualityBadge, RunStateToggle
        ├── device/                        # DeviceCard, DeviceList, DeviceRow,
        │                                  # PositionInput, DeviceColorDot
        ├── viz/                           # RoomCanvas, RoomScene3D (lazy), Trail3D,
        │                                  # ViewToggle, GridLayer, AxisLabels,
        │                                  # AnchorMarker, TagMarker, TrailLine
        ├── layout/                        # AppShell, TopBar, PageHeader
        ├── wizard/                        # WizardShell, WizardStep, ProgressBar
        └── util/                          # ApiClient, AppState, Poller, PlaybackControls

deploy/
└── uwbp-frontend.service                  # systemd-Unit (kopiert nach /etc/systemd/system/)

Makefile                                   # Deployment-Pipeline
.env.example                               # dokumentierte Vorlage
README.md                                  # Deploy-Anleitung
DOCS_FRONTEND.md                           # diese Datei
```

---

## 9. Code-Qualität und Konventionen

- **`npm run check`**: `svelte-kit sync && svelte-check --tsconfig ./jsconfig.json --tsgo` — 0 Errors, 0 Warnings.
- **`npm run lint`**: `prettier --check . && eslint .` — 0 Probleme.
- **`npm run format`**: formatiert alles via Prettier mit svelte-Plugin.
- **Sprachregeln**:
  - Variablen, Funktionen, Komponenten, Code-Kommentare: **Englisch**.
  - UI-Texte (für den Endnutzer sichtbar): **Deutsch**.
  - Commit-Messages: Englisch, kurz, einzeilig, ohne Co-Author-Trailer.
- **Kommentar-Regeln** (Spec):
  - Keine erklärenden Kommentare im Code; gute Namen genügen.
  - Erlaubt sind Section-Marker wie `// ---- state ----`.
  - JSDoc nur für Type-Hints, nicht zur Funktionsbeschreibung.
- **Komponenten unter 200 Zeilen** (mit Ausnahmen wie `RoomCanvas` und `ApiClient` mit Begründung im Code).
- **Naming**: Komponenten PascalCase (`DeviceCard.svelte`), Boolean-Props mit `is`-/`has`-/`should`-Prefix, Event-Handler-Props mit `on`-Prefix.

---

## 10. Bekannte Limitierungen

- **Polling statt Push**: Live-Updates via REST-Polling, nicht WebSocket/SSE. Latenz im Default 80 ms, was für UWB-Indoor-Tracking ausreichend ist, aber höher als ein Push-Stream wäre. Migration ist im Code vorbereitet (siehe nächster Abschnitt).
- **Keine Authentifizierung**: Spec-Vorgabe — das System läuft im geschlossenen WLAN. In offenen Netzwerken wäre eine Login-Stufe nötig.
- **Approval-Set ist Browser-lokal**: Wird in `localStorage` pro Browser gehalten, nicht im Backend. Wenn der Nutzer den Browser wechselt, muss er den Wizard erneut laufen lassen.
- **Mock-Daten**: Die Mock-Tags bewegen sich auf Kreisbahnen (sin/cos), keine realistische Pfad-Simulation. Dient nur als visueller Smoke-Test.

---

## 11. Geplante Erweiterungen

- **WebSocket-/SSE-Stream**: Sobald das Backend `GET /api/stream/positions` als Server-Sent-Events bereitstellt, kann der Positions-Poller im `AppState.svelte` ohne Eingriff in andere Komponenten gegen einen `EventSource`-Listener getauscht werden. Reconnect-Backoff (250 ms → 1 s → 5 s) ist im README skizziert.
- **Backend-DELETE für Devices**: Aktuell wird beim „Vergessen"-Klick im Frontend ein DELETE abgesetzt; je nach Backend-Stand kann dies noch als Stub fungieren.
- **3D-Trail-Linienstärke**: Three.js' `LineBasicMaterial` unterstützt keine variable Linienstärke; eine Migration auf `Line2`/`LineMaterial` aus `three/examples/jsm/lines/` würde geschwindigkeits-modulierte Stärke wie im 2D ermöglichen.
- **i18n**: Aktuell deutsch hardcoded. Bei Bedarf ließe sich ein Light-Wrapper mit zwei Wörterbüchern über Context bereitstellen.

---

## 12. Verwendete Bibliotheken — Vollständige Liste

`dependencies` (Production):
- `@threlte/core`, `@threlte/extras` — Three.js für Svelte
- `three` — 3D-Engine
- `lucide-svelte` — Icon-Set
- `dayjs` — Date-Formatierung
- `flatpickr` — Date-Range-Picker

`devDependencies`:
- `@sveltejs/kit`, `@sveltejs/adapter-node`, `@sveltejs/vite-plugin-svelte`, `svelte`, `vite` — Framework und Build
- `svelte-check`, `typescript`, `@types/node`, `@typescript/native-preview` — Type-Inferenz und Diagnose
- `prettier`, `prettier-plugin-svelte` — Formatter
- `eslint`, `eslint-plugin-svelte`, `@eslint/js`, `globals` — Linter

Keine Test-Frameworks (Vitest/Playwright) eingerichtet — bei Bedarf nachrüstbar.

---

## 13. Zusammenfassung

Das Frontend ist eine **vollständig in Svelte 5 (Runes-Mode) implementierte SPA** mit SSR-Wrapping über SvelteKit, die als Node-Service auf dem Pi läuft. Sie deckt sieben User-Flows ab (Dashboard, Wizard, Devices, Anchors, Historie, Einstellungen, plus die globalen Layouts), wiederverwendet eine zentrale Visualisierungskomponente in 2D und 3D, hat ein robustes Live-Daten-Pipeline-Design mit Stacking-Schutz und Server-Side-Proxying, und ist über ein Staging-fähiges Makefile als systemd-Unit deploybar. Code-Qualität und Konventionen sind durch automatisierte Checks (Prettier, ESLint, svelte-check) auf null Befunde getrimmt.

Es ist das **vollständige Bedien- und Visualisierungs-Layer** des UWBP-Systems — ohne dieses Frontend wäre das Backend ein reiner REST-Endpoint ohne Bedienoberfläche.
