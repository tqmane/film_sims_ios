APP_PATH := xtool/FilmSims.app
BUNDLE_ID := com.tqmane.filmsim

.PHONY: sim

sim:
	xtool dev build --triple arm64-apple-ios-simulator
	@find "$(APP_PATH)/Frameworks" -name "*.framework" | while read fw; do \
		binary="$$fw/$$(basename $$fw .framework)"; \
		if [ -f "$$binary" ] && file "$$binary" | grep -q "ar archive"; then \
			echo "Removing static framework: $$(basename $$fw)"; \
			rm -rf "$$fw"; \
		fi; \
	done
	xcrun simctl install booted "$(APP_PATH)"
	xcrun simctl launch booted "$(BUNDLE_ID)"
