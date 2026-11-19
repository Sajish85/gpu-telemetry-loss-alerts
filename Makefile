# One command: `make test`
# Needs promtool (Prometheus 3.5.0 was used for the recorded run; see TEST-OUTPUTS.md).
# Override the binary with:  make test PROMTOOL=/path/to/promtool
# No GPU, exporter, cluster or Prometheus server is involved: all series are synthetic.
#
# Recipes call promtool by its bare name. If PROMTOOL is a path, its directory is put
# first on PATH, so echoed commands (and TEST-OUTPUTS.md) carry no absolute paths.
# File arguments are relative to this directory.

PROMTOOL ?= promtool
RULES        := rules/dcgm-telemetry-loss.rules.yaml
RULES_LEGACY := rules/dcgm-telemetry-loss.legacy-4.8.rules.yaml

PROMTOOL_BIN := $(notdir $(PROMTOOL))
ifneq ($(findstring /,$(PROMTOOL)),)
export PATH := $(patsubst %/,%,$(dir $(abspath $(PROMTOOL)))):$(PATH)
endif

.PHONY: test check unit unit-legacy mutation versions

test: versions check unit unit-legacy mutation
	@echo "ALL CHECKS PASSED"

versions:
	@$(PROMTOOL_BIN) --version | head -1

# `</dev/null` forces a shell: GNU make 3.81 (macOS) runs metachar-free recipes directly
# and then ignores the exported PATH above.
check:
	$(PROMTOOL_BIN) check rules $(RULES) $(RULES_LEGACY) </dev/null

unit:
	cd tests && $(PROMTOOL_BIN) test rules rules_test.yaml

unit-legacy:
	cd tests && $(PROMTOOL_BIN) test rules rules_test.legacy-4.8.yaml

mutation:
	bash scripts/mutation-test.sh $(PROMTOOL_BIN) $(RULES) tests/rules_test.yaml
