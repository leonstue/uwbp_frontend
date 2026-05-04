# UWBP Frontend

Frontend für das UWBP Indoor-Positioning-System. Svelte 5, SvelteKit und `adapter-node`.

Das Projekt besteht aus zwei Teilen:

- Frontend: <https://github.com/leonstue/uwbp_frontend>
- Backend: <https://github.com/leonstue/uwbp_server>

Das Frontend stellt das Dashboard für das UWBP-System bereit. Das Backend läuft auf dem Raspberry Pi, stellt die API bereit und verwaltet das WLAN für die ESP32-Geräte.

Das Backend wird separat gebaut und deployed. Für den vollständigen Betrieb müssen Backend und Frontend eingerichtet sein.

---

## Voraussetzungen

Backend- und Frontend-Projekt müssen bereits lokal auf dem Raspberry Pi vorhanden sein.

In dieser README wird folgender Platzhalter verwendet:

```text
<FRONTEND_DIR> = lokaler Pfad zum Frontend-Projekt
```

Das gebaute Frontend wird unter folgendem Pfad deployed:

```text
/opt/uwbp/frontend
```

---

## Live-Konfiguration für das Deployment

Für das Deployment muss das Frontend im Live-Modus gebaut werden. Dafür wird im Frontend-Projekt eine `.env`-Datei angelegt bzw. angepasst:

```env
VITE_API_URL=/api
VITE_BACKEND_URL=http://uwbp:8080
```

`VITE_API_URL=/api` sorgt dafür, dass das Frontend `/api` als API-Pfad verwendet.

`VITE_BACKEND_URL=http://uwbp:8080` verweist auf den UWBP-Backend-Server. Dieser Hostname funktioniert nur, wenn der Alias `uwbp` im vom Raspberry Pi bereitgestellten Netzwerk korrekt aufgelöst wird.

Wenn der Alias noch nicht funktioniert, muss alternativ die erreichbare IP-Adresse des Raspberry Pi verwendet werden, zum Beispiel:

```env
VITE_API_URL=/api
VITE_BACKEND_URL=http://10.42.0.1:8080
```

Wichtig: Die `.env`-Datei muss vor `npm run build` gesetzt sein, damit das Frontend mit der Live-Konfiguration gebaut wird.

Wenn `VITE_API_URL` leer bzw. nicht gesetzt ist, läuft das Frontend im Mock-Modus. Das ist für das Deployment nicht gewünscht.

---

## Dev

```bash
npm install
npm run dev
```

Default läuft das Frontend im Mock-Modus mit in-memory Devices und simulierter Tag-Bewegung.

Um in der Entwicklung gegen das echte Backend zu arbeiten, wird ebenfalls die `.env`-Konfiguration verwendet:

```env
VITE_API_URL=/api
VITE_BACKEND_URL=http://uwbp:8080
```

`/api`-Requests gehen im Entwicklungsbetrieb über den Vite-Proxy an `VITE_BACKEND_URL`. Dadurch entsteht im Dev-Betrieb kein CORS-Problem.

---

## Node.js und npm installieren

```bash
sudo apt update
sudo apt upgrade -y

sudo apt install -y nodejs npm
sudo npm install -g npm@latest
sudo npm install -g n
sudo n stable
```

---

## Build

Vor dem Build muss die Live-Konfiguration in `.env` gesetzt sein.

```bash
cd <FRONTEND_DIR>
npm install
npm run build
```

Nach erfolgreichem Build liegt das gebaute Frontend im Ordner:

```text
<FRONTEND_DIR>/build
```

Lokal kann der Production-Server grundsätzlich mit `npm start` gestartet werden. Der Server führt `node build` aus und hört auf `$PORT`, standardmäßig auf Port 3000.

---

## Gebautes Frontend deployen

Es wird nur das gebaute Frontend-Artefakt nach `/opt/uwbp/frontend` kopiert.

```bash
sudo rm -rf /opt/uwbp/frontend
sudo mkdir -p /opt/uwbp/frontend

sudo cp -a <FRONTEND_DIR>/build /opt/uwbp/frontend/build
sudo cp -a <FRONTEND_DIR>/package.json /opt/uwbp/frontend/package.json
sudo cp -a <FRONTEND_DIR>/package-lock.json /opt/uwbp/frontend/package-lock.json
sudo cp -a <FRONTEND_DIR>/node_modules /opt/uwbp/frontend/node_modules
```

---

## Frontend-Service-Datei

Im Frontend-Repository liegt die systemd-Service-Datei unter:

```text
<FRONTEND_DIR>/deploy/uwbp-frontend.service
```

Die Service-Datei startet das gebaute Frontend auf Port 80 und erst nach dem Backend-Service:

```ini
[Unit]
Description=UWBP Frontend Server
Requires=uwbp-server.service
After=uwbp-server.service

[Service]
Type=simple
WorkingDirectory=/opt/uwbp/frontend
ExecStart=/usr/local/bin/node build
Restart=always
RestartSec=5
User=root
Environment=HOST=0.0.0.0
Environment=PORT=80

[Install]
WantedBy=multi-user.target
```

Da das Frontend auf Port 80 gestartet wird, wird der Service hier mit `User=root` ausgeführt.

---

## Frontend-Service installieren

```bash
sudo cp <FRONTEND_DIR>/deploy/uwbp-frontend.service /etc/systemd/system/uwbp-frontend.service
sudo systemctl daemon-reload
sudo systemctl enable uwbp-frontend.service
```

Danach wird der Raspberry Pi neu gestartet:

```bash
sudo reboot
```

---

## Nach dem Reboot testen

Nach dem Neustart kann geprüft werden, ob der Frontend-Service erfolgreich automatisch gestartet wurde:

```bash
systemctl status uwbp-frontend.service --no-pager
journalctl -u uwbp-frontend.service -n 50 --no-pager
```

Wenn der Service `active (running)` ist, wurde das Frontend erfolgreich gestartet.

Das Dashboard ist anschließend über Port 80 erreichbar, zum Beispiel:

```text
http://<PI-IP>
```

Wenn das Backend den Access Point mit der Adresse `10.42.0.1` bereitstellt:

```text
http://10.42.0.1
```

---

## Skripte

| Befehl | Zweck |
| --- | --- |
| `npm run dev` | Vite Dev-Server starten |
| `npm run build` | Production-Build erzeugen |
| `npm start` | Production-Server starten |
| `npm run preview` | Build lokal testen |
| `npm run lint` | Prettier und ESLint prüfen |
| `npm run format` | Code formatieren |

---

## Mock vs. Live

```text
VITE_API_URL leer oder nicht gesetzt  -> Mock-Modus
VITE_API_URL=/api                    -> Live-Modus über API-Pfad /api
```

Für das Deployment muss der Live-Modus verwendet werden.
