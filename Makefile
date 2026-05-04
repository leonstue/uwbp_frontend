DEPLOY_DIR := /opt/uwbp/frontend
SERVICE_FILE := deploy/uwbp-frontend.service
SYSTEMD_SERVICE := /etc/systemd/system/uwbp-frontend.service

VITE_API_URL ?= /api
VITE_BACKEND_URL ?= http://uwbp:8080

.PHONY: help install-deps set-live-env build deploy install-service

help:
	@echo "Available targets:"
	@echo "  make install-deps      - install Node.js, npm, latest npm and stable node via n"
	@echo "  make set-live-env      - write .env for live backend"
	@echo "  make build             - install npm dependencies and build frontend"
	@echo "  make deploy            - copy built frontend to /opt/uwbp/frontend"
	@echo "  make install-service   - install and enable systemd service"
	@echo ""
	@echo "VITE_API_URL=$(VITE_API_URL)"
	@echo "VITE_BACKEND_URL=$(VITE_BACKEND_URL)"

install-deps:
	apt update
	apt upgrade -y
	apt install -y nodejs npm
	npm install -g npm@latest
	npm install -g n
	n stable

set-live-env:
	printf "VITE_API_URL=$(VITE_API_URL)\nVITE_BACKEND_URL=$(VITE_BACKEND_URL)\n" > .env

build:
	npm install
	npm run build

deploy:
	rm -rf $(DEPLOY_DIR)
	mkdir -p $(DEPLOY_DIR)
	cp -a build $(DEPLOY_DIR)/build
	cp -a package.json $(DEPLOY_DIR)/package.json
	cp -a node_modules $(DEPLOY_DIR)/node_modules

install-service:
	cp $(SERVICE_FILE) $(SYSTEMD_SERVICE)
	systemctl daemon-reload
	systemctl enable uwbp-frontend.service
