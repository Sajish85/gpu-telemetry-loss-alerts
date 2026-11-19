#!/usr/bin/env bash
# Renders the chart's PrometheusRule and checks it with promtool:
#   1. `promtool check rules` on the rendered rule groups
#   2. `promtool test rules` against synthetic series (rules_test.yaml)
# No GPU, cluster or Prometheus server is involved.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/dcgm-exporter-contrib/promtool"
HELM="$ROOT/.tools/helm-dist/darwin-arm64/helm"
PROMTOOL="$ROOT/.tools/prom-dist/prometheus-3.5.0.darwin-arm64/promtool"
PY="$ROOT/.venv/bin/python"
export HELM_CACHE_HOME="$ROOT/dcgm-exporter-contrib/.helm/cache"
export HELM_CONFIG_HOME="$ROOT/dcgm-exporter-contrib/.helm/config"
export HELM_DATA_HOME="$ROOT/dcgm-exporter-contrib/.helm/data"

"$HELM" template dcgm-exporter "$ROOT/dcgm-exporter-contrib/dcgm-exporter/deployment" \
  -n gpu-monitoring --set prometheusRule.enabled=true \
  --show-only templates/prometheus-rule.yaml > "$HERE/rendered.yaml"

# A PrometheusRule's spec has the same shape as a Prometheus rule file.
"$PY" -c '
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
yaml.safe_dump(doc["spec"], open(sys.argv[2], "w"), sort_keys=False)
' "$HERE/rendered.yaml" "$HERE/rules.yaml"

"$PROMTOOL" check rules "$HERE/rules.yaml"
(cd "$HERE" && "$PROMTOOL" test rules rules_test.yaml)
