# uwbp_frontend

Frontend für das UWBP Indoor-Positioning-System. Svelte 5 (Runes), SvelteKit, adapter-node.

## Dev

```sh
npm install
npm run dev
```

Default läuft im **Mock-Modus** (in-memory Devices + simulierte Tag-Bewegung). Um gegen das echte Backend zu fahren, in `.env`:

```
VITE_API_URL=/api
VITE_BACKEND_URL=http://uwbp:8080
```

`/api` Requests gehen über den Vite-Proxy an `VITE_BACKEND_URL` — kein CORS-Problem.

## Build

```sh
npm run build
npm start   # node build, hört auf $PORT (default 3000)
```

## Deployment Pi

```sh
git clone <repo> /home/pi/uwbp_frontend
cd /home/pi/uwbp_frontend
npm install
npm run build
PORT=3000 HOST=0.0.0.0 node build
```

Optional Port 80 für `http://uwbp` ohne Port-Angabe:

```sh
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j REDIRECT --to-port 3000
```

Beim Echt-Betrieb sollte das Backend dieselbe Origin sein (Reverse-Proxy oder Pfad-Spiegelung), damit `fetch('/api/...')` weiter funktioniert.

## Skripte

| Befehl            | Zweck                       |
| ----------------- | --------------------------- |
| `npm run dev`     | Vite Dev-Server             |
| `npm run build`   | Production-Build (`build/`) |
| `npm start`       | Production-Server starten   |
| `npm run preview` | Build lokal testen          |
| `npm run lint`    | Prettier + ESLint Check     |
| `npm run format`  | Code formatieren            |

## Mock vs. Live

`VITE_API_URL` leer → Mock. Gesetzt → Real (über Vite-Proxy zu `VITE_BACKEND_URL`).
