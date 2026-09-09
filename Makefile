SWIFT ?= swift

BOLD  := \033[1m
CYAN  := \033[36m
GREEN := \033[32m
RESET := \033[0m

.DEFAULT_GOAL := help

# -- Development --------------------------------------------------------------

.PHONY: build test run check validate

build: ## Build debug artifacts (must be warning-free)
	@$(SWIFT) build

test: ## Run the domain-kit unit tests
	@$(SWIFT) test

run: ## Run the debug app from the terminal (unbundled)
	@$(SWIFT) run Meantime

validate: ## Check repository invariants
	@bash scripts/validate.sh

check: ## Build + test + validate
	@printf '\n$(BOLD)[1/3] Building$(RESET)\n'
	@$(MAKE) --no-print-directory build
	@printf '\n$(BOLD)[2/3] Testing$(RESET)\n'
	@$(MAKE) --no-print-directory test
	@printf '\n$(BOLD)[3/3] Validating$(RESET)\n'
	@$(MAKE) --no-print-directory validate
	@printf '\n$(GREEN)[ok] All checks passed$(RESET)\n\n'

# -- Assets -------------------------------------------------------------------

.PHONY: icon installer-assets regions web-assets screenshots

icon: ## Regenerate the app icon (Support/AppIcon.icns)
	@$(SWIFT) scripts/make-icon.swift

installer-assets: icon ## Regenerate the DMG volume icon and background art
	@$(SWIFT) scripts/render-installer-icon.swift
	@$(SWIFT) scripts/render-dmg-background.swift

regions: ## Regenerate the time-zone → region table from the system tz database
	@bash scripts/make-regions.sh

web-assets: ## Regenerate the social card and the website's app-icon sizes
	@$(SWIFT) scripts/render-web-assets.swift

screenshots: ## Refresh README/website screenshots from the real app
	@bash scripts/capture-screenshots.sh

# -- Release ------------------------------------------------------------------

.PHONY: app dmg notarize sign-update appcast keys

app: ## Build the Release .app (ad-hoc unless DEVELOPER_ID_IDENTITY is set)
	@bash scripts/package-app.sh

dmg: app installer-assets ## Build the installer DMG
	@bash scripts/make-dmg.sh

notarize: ## Notarize + staple a signed DMG: args: DMG, env NOTARY_PROFILE
	@bash scripts/notarize.sh $(DMG)

sign-update: ## Print the appcast signature for a release zip: args: ZIP
	@bash scripts/sign-update.sh $(ZIP)

# SIG is single-quoted below: it carries the double-quoted attributes that
# sign_update prints, which the recipe's own shell would otherwise strip.
appcast: ## Update appcast.xml: args: VERSION BUILD ZIP "SIG"
	@bash scripts/make-appcast.sh $(VERSION) $(BUILD) $(ZIP) '$(SIG)'

keys: ## Generate the Sparkle signing key (Keychain) and set the public key
	@bash scripts/make-keys.sh

# -- Maintenance --------------------------------------------------------------

.PHONY: clean

clean: ## Remove build artifacts
	@$(SWIFT) package clean
	@rm -rf .build build

# -- Help ---------------------------------------------------------------------

.PHONY: help

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "; printf "\n$(BOLD)Meantime$(RESET): world clocks in your menu bar\n"} \
		/^# -- / {n = $$0; gsub(/(^# -- | -+$$)/, "", n); printf "\n$(BOLD)%s$(RESET)\n", n} \
		/^[a-zA-Z_-]+:.*## / {printf "  $(CYAN)make %-16s$(RESET) %s\n", $$1, $$2} \
		END {printf "\n"}' $(MAKEFILE_LIST)
