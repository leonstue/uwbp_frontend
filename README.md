# UWBP Frontend

Frontend für das UWBP Indoor-Positioning-System. Svelte 5, SvelteKit und `adapter-node`.

Repos:

- Frontend: <https://github.com/leonstue/uwbp_frontend>
- Backend: <https://github.com/leonstue/uwbp_server>

Das Frontend stellt das Dashboard bereit und wird auf dem Raspberry Pi als systemd-Service auf Port 80 gestartet.

Das Backend muss ebenfalls deployed sein und die API bereitstellen.

---

## Deploymentanleitung

Das Frontend-Projekt muss bereits lokal auf dem Raspberry Pi vorhanden sein.

In dieser README wird folgender Platzhalter verwendet:

```text
<FRONTEND_DIR> = lokaler Pfad zum Frontend-Projekt
```

Das gebaute Frontend wird unter folgendem Pfad deployed:

```text
/opt/uwbp/frontend
```

### Frontend vollständig deployen

```bash
cd <FRONTEND_DIR>

sudo make install-deps
make set-live-env
make build
sudo make deploy
sudo make install-service
sudo reboot
```

Nach dem Neustart prüfen:

```bash
systemctl status uwbp-frontend.service --no-pager
journalctl -u uwbp-frontend.service -n 50 --no-pager
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

Für das Deployment muss das Frontend im Live-Modus gebaut werden.

Das Make-Target `make set-live-env` erstellt dafür eine `.env`-Datei mit:

```env
VITE_API_URL=/api
VITE_BACKEND_URL=http://uwbp:8080
```

Falls der Alias `uwbp` noch nicht funktioniert, kann die Backend-URL beim Setzen der `.env` überschrieben werden:

```bash
make set-live-env VITE_BACKEND_URL=http://10.42.0.1:8080
```

Danach muss das Frontend neu gebaut und deployed werden:

```bash
make build
sudo make deploy
sudo make install-service
sudo reboot
```

---

## Make-Targets

| Target | Beschreibung |
| --- | --- |
| `make help` | Zeigt alle verfügbaren Make-Targets an. |
| `sudo make install-deps` | Installiert Node.js, npm, aktualisiert npm und installiert eine aktuelle stabile Node.js-Version über `n`. |
| `make set-live-env` | Erstellt die `.env`-Datei für den Live-Betrieb mit `VITE_API_URL=/api` und `VITE_BACKEND_URL=http://uwbp:8080`. |
| `make build` | Installiert npm-Abhängigkeiten und baut das Frontend. |
| `sudo make deploy` | Kopiert das gebaute Frontend nach `/opt/uwbp/frontend`. |
| `sudo make install-service` | Installiert den systemd-Service und aktiviert den Autostart. |

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

## systemd-Service

Der Frontend-Service wird durch `sudo make install-service` installiert.

Erwarteter Service-Name:

```text
uwbp-frontend.service
```

Status prüfen:

```bash
systemctl status uwbp-frontend.service --no-pager
```

Logs anzeigen:

```bash
journalctl -u uwbp-frontend.service -n 50 --no-pager
```

Der Service startet das Frontend auf Port 80.
