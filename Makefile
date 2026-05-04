DEPLOY_DIR      := /opt/uwbp/frontend
SERVICE_FILE    := deploy/uwbp-frontend.service
SYSTEMD_SERVICE := /etc/systemd/system/uwbp-frontend.service
SERVICE_NAME    := uwbp-frontend.service

VITE_API_URL ?= http://uwbp.:8080

.PHONY: help install-deps set-live-env build deploy deploy-artifact install-service \
        start logs clean-artifacts clean

help:
	@echo "Available targets:"
	@echo "  make deploy           - install deps, set live env, build, deploy artifact, install service and start it"
	@echo "  make clean            - stop/remove service, remove deployed artifact and remove local build/npm artifacts"
	@echo "  make clean-artifacts  - remove only deployed artifact from /opt; service stays registered and may fail until redeployed"
	@echo "  make logs             - show recent logs of deployed frontend service"
	@echo ""
	@echo "  make install-deps     - install Node.js, npm, latest npm and stable Node via n"
	@echo "  make set-live-env     - write .env for live backend"
	@echo "  make build            - install npm dependencies and build frontend"
	@echo "  make deploy-artifact  - copy built frontend to /opt/uwbp/frontend"
	@echo "  make install-service  - install and enable systemd service"
	@echo "  make start            - start/restart frontend service now"
	@echo ""
	@echo "VITE_API_URL=$(VITE_API_URL)"

install-deps:
	sudo apt update
	sudo apt upgrade -y
	sudo apt install -y nodejs npm
	sudo npm install -g npm@latest
	sudo npm install -g n
	sudo n stable

set-live-env:
	printf "VITE_API_URL=$(VITE_API_URL)\n" > .env

build:
	npm install
	npm run build

deploy: install-deps set-live-env build deploy-artifact install-service start

deploy-artifact:
	sudo rm -rf $(DEPLOY_DIR)
	sudo mkdir -p $(DEPLOY_DIR)
	sudo cp -a build $(DEPLOY_DIR)/build
	sudo cp -a package.json $(DEPLOY_DIR)/package.json
	sudo cp -a node_modules $(DEPLOY_DIR)/node_modules

install-service:
	sudo cp $(SERVICE_FILE) $(SYSTEMD_SERVICE)
	sudo systemctl daemon-reload
	sudo systemctl enable $(SERVICE_NAME)

start:
	sudo systemctl restart $(SERVICE_NAME)

logs:
	journalctl -u $(SERVICE_NAME) -n 50 --no-pager

clean-artifacts:
	sudo rm -rf $(DEPLOY_DIR)

clean:
	sudo systemctl disable --now $(SERVICE_NAME) 2>/dev/null || true
	sudo rm -f $(SYSTEMD_SERVICE)
	sudo systemctl daemon-reload
	sudo systemctl reset-failed
	sudo rm -rf $(DEPLOY_DIR)
	rm -rf build
	rm -rf .svelte-kit
	rm -rf node_modules
	rm -f .env
