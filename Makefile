DEPLOY_DIR      := /opt/uwbp/frontend
STAGING_DIR     := /opt/uwbp/frontend.next
SERVICE_FILE    := deploy/uwbp-frontend.service
SYSTEMD_SERVICE := /etc/systemd/system/uwbp-frontend.service
SERVICE_NAME    := uwbp-frontend.service

VITE_API_URL ?= /api
BACKEND_URL  ?= http://localhost:8080

.PHONY: help install-deps set-live-env build deploy deploy-artifact install-service \
        start stop logs clean-artifacts clean

help:
	@echo "Available targets:"
	@echo "  make deploy           - install deps, set live env, build, stage artifact, enable service for next boot (running service is NOT restarted)"
	@echo "  make clean            - stop/remove service, remove deployed artifact and remove local build/npm artifacts"
	@echo "  make clean-artifacts  - remove only deployed artifact from /opt; service stays registered and may fail until redeployed"
	@echo "  make logs             - show recent logs of deployed frontend service"
	@echo ""
	@echo "  make install-deps     - install Node.js, npm, latest npm and stable Node via n"
	@echo "  make set-live-env     - write .env for live backend"
	@echo "  make build            - install npm dependencies and build frontend"
	@echo "  make deploy-artifact  - stage built frontend to /opt/uwbp/frontend.next (active on next service start)"
	@echo "  make install-service  - install and enable systemd service (starts on next boot)"
	@echo "  make start            - manually start/restart frontend service now"
	@echo "  make stop             - manually stop frontend service now"
	@echo ""
	@echo "VITE_API_URL=$(VITE_API_URL)"
	@echo "BACKEND_URL=$(BACKEND_URL)"

install-deps:
	sudo apt update
	sudo apt upgrade -y
	sudo apt install -y nodejs npm
	sudo npm install -g npm@latest
	sudo npm install -g n
	sudo n stable

set-live-env:
	printf "VITE_API_URL=$(VITE_API_URL)\nVITE_BACKEND_URL=$(BACKEND_URL)\nBACKEND_URL=$(BACKEND_URL)\n" > .env

build:
	npm install
	npm run build

deploy: install-deps set-live-env build deploy-artifact install-service

deploy-artifact:
	sudo rm -rf $(STAGING_DIR)
	sudo mkdir -p $(STAGING_DIR)
	sudo cp -a build $(STAGING_DIR)/build
	sudo cp -a package.json $(STAGING_DIR)/package.json
	sudo cp -a node_modules $(STAGING_DIR)/node_modules
	sudo cp -a .env $(STAGING_DIR)/.env
	@echo "staged at $(STAGING_DIR) — wird beim nächsten Service-Start aktiv"

install-service:
	sudo cp $(SERVICE_FILE) $(SYSTEMD_SERVICE)
	sudo systemctl daemon-reload
	sudo systemctl enable $(SERVICE_NAME)

start:
	sudo systemctl restart $(SERVICE_NAME)

stop:
	sudo systemctl stop $(SERVICE_NAME)

logs:
	journalctl -u $(SERVICE_NAME) -n 50 --no-pager

clean-artifacts:
	sudo rm -rf $(DEPLOY_DIR) $(STAGING_DIR)

clean:
	sudo systemctl disable --now $(SERVICE_NAME) 2>/dev/null || true
	sudo rm -f $(SYSTEMD_SERVICE)
	sudo systemctl daemon-reload
	sudo systemctl reset-failed
	sudo rm -rf $(DEPLOY_DIR) $(STAGING_DIR)
	rm -rf build
	rm -rf .svelte-kit
	rm -rf node_modules
	rm -f .env
