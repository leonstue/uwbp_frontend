# UWBP Frontend

Frontend für das UWBP Indoor-Positioning-System. Svelte 5, SvelteKit und `adapter-node`.

Repos:

- Frontend: <https://github.com/leonstue/uwbp_frontend>
- Backend: <https://github.com/leonstue/uwbp_server>

Das Frontend stellt das Dashboard bereit und läuft auf dem Raspberry Pi als systemd-Service auf Port 80.

---

## Deploymentanleitung

Das Frontend-Projekt muss bereits lokal auf dem Raspberry Pi vorhanden sein.

```text
<FRONTEND_DIR> = lokaler Pfad zum Frontend-Projekt
```

Das gebaute Frontend wird unter folgendem Pfad deployed:

```text
/opt/uwbp/frontend
```

Für die Deployment-Befehle wird `make` benötigt. Falls `make` noch nicht installiert ist:

```bash
sudo apt update
sudo apt install -y make
```

### Deployment ausführen

```bash
cd <FRONTEND_DIR>
make deploy
```

`make deploy` installiert Node.js und npm, erstellt die Live-`.env`, baut das Frontend, **staged** das gebaute Artefakt nach `/opt/uwbp/frontend.next` und installiert den systemd-Service. Ein bereits laufender Service wird **nicht angefasst** und läuft auf der alten Version weiter. Beim nächsten Service-Start (Reboot oder `make start`) promoviert ein `ExecStartPre`-Hook den Staging-Ordner zur aktiven Version. Soll die neue Version sofort laufen: `make start`.

Falls der Alias `uwbp` noch nicht funktioniert, kann die Backend-URL überschrieben werden:

```bash
make deploy VITE_BACKEND_URL=http://10.42.0.1:8080
```

### Deployment testen

```bash
systemctl status uwbp-frontend.service --no-pager
make logs
```

Wenn der Service `active (running)` ist, wurde das Frontend erfolgreich gestartet.

Das Dashboard ist anschließend erreichbar unter:

```text
http://<PI-IP>
```

Wenn der Raspberry Pi den Access Point mit `10.42.0.1` bereitstellt:

```text
http://10.42.0.1
```

---

## Live-Konfiguration

`make set-live-env` erstellt eine `.env`-Datei mit:

```env
VITE_API_URL=/api
VITE_BACKEND_URL=http://uwbp:8080
```

Der Standardwert kann beim Aufruf überschrieben werden:

```bash
make set-live-env VITE_BACKEND_URL=http://10.42.0.1:8080
```

---

## Make-Targets

| Target | Beschreibung |
| --- | --- |
| `make help` | Zeigt alle verfügbaren Make-Targets an. |
| `make deploy` | Installiert Abhängigkeiten, setzt die Live-`.env`, baut das Frontend, deployed das Artefakt und aktiviert den Service für den nächsten Reboot. Startet ihn nicht sofort. |
| `make clean` | Stoppt und entfernt den Service, löscht das deployte Artefakt und entfernt lokale Build- und npm-Artefakte. |
| `make clean-artifacts` | Löscht nur das deployte Artefakt unter `/opt/uwbp/frontend`. Der Service bleibt registriert und kann danach fehlschlagen, bis erneut deployed wurde. |
| `make logs` | Zeigt die letzten Logs des Frontend-Service an. |
| `make install-deps` | Installiert Node.js, npm, aktualisiert npm und installiert eine aktuelle stabile Node.js-Version über `n`. |
| `make set-live-env` | Erstellt die `.env`-Datei für den Live-Betrieb. |
| `make build` | Installiert npm-Abhängigkeiten und baut das Frontend. |
| `make deploy-artifact` | Kopiert das gebaute Frontend nach `/opt/uwbp/frontend`. |
| `make install-service` | Installiert und aktiviert den systemd-Service (Autostart bei Reboot). |
| `make start` | Startet bzw. restartet den Frontend-Service sofort (manuell). |
| `make stop` | Stoppt den Frontend-Service sofort (manuell). |

---

## npm-Skripte

| Befehl | Zweck |
| --- | --- |
| `npm run dev` | Vite Dev-Server starten |
| `npm run build` | Production-Build erzeugen |
| `npm start` | Production-Server starten |
| `npm run preview` | Build lokal testen |
| `npm run lint` | Prettier und ESLint prüfen |
| `npm run format` | Code formatieren |

---

## Live-Daten-Architektur

Das Frontend liest Live-Positionsdaten aktuell per **HTTP-Polling** (zentrale Async-Loop in `src/lib/components/util/Poller.svelte`). Garantien:

- Pro Endpoint maximal **eine** Request gleichzeitig in der Luft (in-flight Guard in `AppState.svelte`).
- Jede Request hat **`AbortController`-Timeout** (`VITE_REQUEST_TIMEOUT_MS`, default 1500 ms).
- Nach Fehlern Exponential-Backoff (max 2 s) für Positions-Polling.
- Polling-Loops werden bei Component-Unmount sauber abgeräumt.
- Single-Source-of-Truth: **nur eine** Polling-Loop pro Endpoint im Layout-`AppState`, nicht in einzelnen Pages.

`VITE_API_URL` wird in `ApiClient.svelte` normalisiert (trailing `/` und `/api` werden entfernt). Konstrukte wie `/api/api/locations` sind damit ausgeschlossen.

### Migration zu WebSocket / SSE

Wenn das Backend einen Stream-Endpoint bekommt (Spec: `GET /api/stream/positions`):

1. In `AppState.svelte` den Positions-`<Poller>` durch einen `EventSource` (SSE) bzw. `new WebSocket(...)` ersetzen.
2. Auf `message`-Event den vorhandenen `pushHistory()`-Pfad weiter nutzen — alle Downstream-Komponenten ändern sich nicht.
3. Reconnect-Backoff (250 ms → 1 s → 5 s) bei `onerror`/`onclose`.
4. Nur **eine** Connection global, kein per-Component-Connect.

Bis dahin bleibt Polling die robuste Default-Lösung.

## Service

Service-Name:

```text
uwbp-frontend.service
```

Status prüfen:

```bash
systemctl status uwbp-frontend.service --no-pager
```

Logs anzeigen:

```bash
make logs
```
