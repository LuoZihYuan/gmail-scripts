s ?= $(if $(filter help,$(MAKECMDGOALS)),,$(error Set script name: make <target> s=rejection-sorter))
t ?= [Gmail] $(s) (dev)

SECRET_FILE = scripts/$(s)/secret.js
SECRET_EXAMPLE = scripts/$(s)/secret.example.js
PLACEHOLDER = YOUR_GEMINI_API_KEY_HERE
WORKFLOW = .github/workflows/deploy.yml
APPSSCRIPT = scripts/$(s)/appsscript.json

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
	@$(MAKE) _link-gcp s=$(s)
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
	@if [ -f $(APPSSCRIPT) ]; then cp $(APPSSCRIPT) $(APPSSCRIPT).bak; fi
	cd scripts/$(s) && clasp create --type standalone --title "$(t)"
	@if [ -f $(APPSSCRIPT).bak ]; then mv $(APPSSCRIPT).bak $(APPSSCRIPT); fi
	@$(MAKE) _install-hook
	@$(MAKE) _link-gcp s=$(s)
	@echo "Initialized scripts/$(s)"

deploy: _ensure-secret _build
	cd scripts/$(s)/build && clasp push --force
	@$(MAKE) _ensure-executable s=$(s)
	cd scripts/$(s)/build && clasp run-function installTrigger

publish: _ensure-secret _build
	cd scripts/$(s)/build && clasp push --force
	cd scripts/$(s)/build && clasp create-version "$$(git rev-parse HEAD)"
	@$(MAKE) _ensure-executable s=$(s)
	cd scripts/$(s)/build && clasp run-function installTrigger

open:
	cd scripts/$(s) && clasp open-script

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
	for f in scripts/$(s)/*.js; do \
		case "$$f" in *secret.example.js) continue;; esac; \
		cp "$$f" scripts/$(s)/build/; \
	done
	cp scripts/$(s)/appsscript.json scripts/$(s)/build/ 2>/dev/null || true
	cp scripts/$(s)/.clasp.json scripts/$(s)/build/ 2>/dev/null || true

_ensure-executable:
	@SCRIPT_ID=$$(grep '"scriptId"' scripts/$(s)/.clasp.json | sed 's/.*"scriptId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'); \
	ACCESS_TOKEN=$$(jq -r '.tokens.default.access_token // .token.access_token // empty' ~/.clasprc.json 2>/dev/null); \
	if [ -z "$$ACCESS_TOKEN" ]; then \
		echo "Could not read access token from ~/.clasprc.json. Run clasp login first."; \
		exit 1; \
	fi; \
	DEPLOYMENTS=$$(curl -s \
		"https://script.googleapis.com/v1/projects/$$SCRIPT_ID/deployments" \
		-H "Authorization: Bearer $$ACCESS_TOKEN"); \
	HAS_EXEC=$$(echo "$$DEPLOYMENTS" | grep -c "EXECUTION_API" || true); \
	if [ "$$HAS_EXEC" = "0" ]; then \
		echo "Creating API Executable deployment..."; \
		curl -s -X POST \
			"https://script.googleapis.com/v1/projects/$$SCRIPT_ID/deployments" \
			-H "Authorization: Bearer $$ACCESS_TOKEN" \
			-H "Content-Type: application/json" \
			-d '{"deploymentConfig":{"description":"API Executable"}}' \
		> /dev/null; \
	fi

_link-gcp:
	@SCRIPT_ID=$$(grep '"scriptId"' scripts/$(s)/.clasp.json | sed 's/.*"scriptId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'); \
	URL="https://script.google.com/home/projects/$$SCRIPT_ID/settings"; \
	echo ""; \
	echo "Link your GCP project to this Apps Script project:"; \
	echo "  1. Click 'Change project' in the page opening in your browser"; \
	echo "  2. Enter your GCP project number"; \
	echo ""; \
	if command -v open >/dev/null 2>&1; then \
		open "$$URL"; \
	elif command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "$$URL"; \
	else \
		echo "  Open: $$URL"; \
	fi; \
	read -p "Done? (y/n) " answer; \
	answer=$$(echo "$$answer" | tr '[:upper:]' '[:lower:]'); \
	if [ "$$answer" != "y" ] && [ "$$answer" != "yes" ]; then \
		echo "You can link the GCP project later via: make open s=$(s)"; \
	fi

_install-hook:
	@if [ ! -f .git/hooks/pre-push ]; then \
		cp hooks/pre-push .git/hooks/pre-push; \
		chmod +x .git/hooks/pre-push; \
		echo "Installed pre-push hook"; \
	fi

_update-workflow:
	@SCRIPTS=$$(ls -d scripts/*/ 2>/dev/null | xargs -I{} basename {} | sed 's/^/          - /'); \
	sed -i.bak '/# SCRIPT_OPTIONS_START/,/# SCRIPT_OPTIONS_END/{/# SCRIPT_OPTIONS_START/!{/# SCRIPT_OPTIONS_END/!d;}}' $(WORKFLOW); \
	{ echo "          - all"; echo "$$SCRIPTS"; } > /tmp/_workflow_scripts.tmp; \
	sed -i.bak "/# SCRIPT_OPTIONS_START/r /tmp/_workflow_scripts.tmp" $(WORKFLOW); \
	rm -f $(WORKFLOW).bak /tmp/_workflow_scripts.tmp; \
	echo "Updated workflow dropdown"

.PHONY: help new init deploy publish open _ensure-secret _build _ensure-executable _link-gcp _install-hook _update-workflow
.DEFAULT_GOAL := help