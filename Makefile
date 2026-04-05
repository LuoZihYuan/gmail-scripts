s ?= $(if $(filter help,$(MAKECMDGOALS)),,$(error Set script name: make <target> s=rejection-sorter))
t ?= [Gmail] $(s) (dev)

SECRET_FILE = scripts/$(s)/secret.js
SECRET_EXAMPLE = scripts/$(s)/secret.example.js
PLACEHOLDER = YOUR_GEMINI_API_KEY_HERE
WORKFLOW = .github/workflows/deploy.yml

help:
	@echo "Usage: make <command> s=<script-name> [t=<title>]"
	@echo ""
	@echo "Commands:"
	@echo "  new      Scaffold a new script and create Apps Script project"
	@echo "  init     Create Apps Script project for an existing script"
	@echo "  deploy   Build, push, and install trigger"
	@echo "  publish  Build, push, version, and install trigger"
	@echo "  open     Open script in Apps Script editor"
	@echo "  help     Show this message"
	@echo ""
	@echo "Example:"
	@echo "  make new s=newsletter-sorter"
	@echo "  make init s=rejection-sorter t='My Custom Title'"
	@echo "  make deploy s=rejection-sorter"

new:
	@if [ -d scripts/$(s) ]; then \
		echo "scripts/$(s) already exists. Use 'make init s=$(s)' instead."; \
		exit 1; \
	fi
	mkdir -p scripts/$(s)
	touch scripts/$(s)/config.js scripts/$(s)/secret.example.js scripts/$(s)/main.js scripts/$(s)/README.md
	cd scripts/$(s) && clasp create --type standalone --title "$(t)"
	@$(MAKE) _install-hook
	@$(MAKE) _update-workflow
	@echo "Created scripts/$(s)"

init:
	@if [ ! -d scripts/$(s) ]; then \
		echo "scripts/$(s) does not exist. Use 'make new s=$(s)' instead."; \
		exit 1; \
	fi
	@if [ -f scripts/$(s)/.clasp.json ]; then \
		echo "scripts/$(s) is already linked to an Apps Script project."; \
		exit 1; \
	fi
	cd scripts/$(s) && clasp create --type standalone --title "$(t)"
	@$(MAKE) _install-hook
	@echo "Initialized scripts/$(s)"

deploy: _ensure-secret _build
	cd scripts/$(s)/build && clasp push --force
	cd scripts/$(s)/build && clasp run installTrigger

publish: _ensure-secret _build
	cd scripts/$(s)/build && clasp push --force
	cd scripts/$(s)/build && clasp version "$$(git rev-parse HEAD)"
	cd scripts/$(s)/build && clasp run installTrigger

open:
	cd scripts/$(s) && clasp open

_ensure-secret:
	@if [ -f $(SECRET_EXAMPLE) ]; then \
		if [ ! -f $(SECRET_FILE) ]; then \
			cp $(SECRET_EXAMPLE) $(SECRET_FILE); \
		fi; \
		if grep -q "$(PLACEHOLDER)" $(SECRET_FILE); then \
			read -p "Enter your Gemini API key: " key; \
			sed -i.bak 's/$(PLACEHOLDER)/'"$$key"'/' $(SECRET_FILE); \
			rm -f $(SECRET_FILE).bak; \
			echo "API key saved to $(SECRET_FILE)"; \
		fi; \
	fi

_build:
	rm -rf scripts/$(s)/build
	mkdir -p scripts/$(s)/build
	cp shared/*.js scripts/$(s)/build/
	cp scripts/$(s)/*.js scripts/$(s)/build/ 2>/dev/null || true
	cp scripts/$(s)/*.json scripts/$(s)/build/ 2>/dev/null || true

_install-hook:
	@if [ ! -f .git/hooks/pre-push ]; then \
		cp hooks/pre-push .git/hooks/pre-push; \
		chmod +x .git/hooks/pre-push; \
		echo "Installed pre-push hook"; \
	fi

_update-workflow:
	@SCRIPTS=$$(ls -d scripts/*/ 2>/dev/null | xargs -I{} basename {} | sed 's/^/          - /' ); \
	sed -i.bak '/# SCRIPT_OPTIONS_START/,/# SCRIPT_OPTIONS_END/{/# SCRIPT_OPTIONS_START/!{/# SCRIPT_OPTIONS_END/!d;}}' $(WORKFLOW); \
	sed -i.bak "/# SCRIPT_OPTIONS_START/a\\
          - all\\
$$SCRIPTS" $(WORKFLOW); \
	rm -f $(WORKFLOW).bak; \
	echo "Updated workflow dropdown"

.PHONY: help new init deploy publish open _ensure-secret _build _install-hook _update-workflow
.DEFAULT_GOAL := help