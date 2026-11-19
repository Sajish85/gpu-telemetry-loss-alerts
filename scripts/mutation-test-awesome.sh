#!/usr/bin/env bash
# Mutation check for the two rules proposed to awesome-prometheus-alerts, run on the
# rendered rule file. The PR rules have no `== 0` expression, so M2 is replaced by M2b.
#   M1   `unless on (instance)` -> `and on (instance)`
#   M2b  `up{job="dcgm-exporter"} == 1 unless` -> `up{job="dcgm-exporter"} == 0 unless`
#   M3   the two proposed rules' `for: 5m` -> `for: 0m`
#   M4   `absent(up{` -> `absent(dcgm_exporter_up{`
# Usage: mutation-test-awesome.sh <promtool> <build/test dir>
set -uo pipefail
PROMTOOL="$1"; BUILD="$2"
RULES="$BUILD/rules/nvidia-gpu/nvidia-dcgm-exporter.yml"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
declare -a NAMES=(M1 M2b M3 M4)
declare -a SEDS=(
  's/unless on (instance)/and on (instance)/'
  's/up{job="dcgm-exporter"} == 1 unless/up{job="dcgm-exporter"} == 0 unless/'
  '/NvidiaDcgmExporter/,/severity/ s/for: 5m/for: 0m/'
  's/absent(up{/absent(dcgm_exporter_up{/'
)
caught=0
for i in "${!NAMES[@]}"; do
  m="${NAMES[$i]}"
  cp -R "$BUILD" "$WORK/$m"
  sed "${SEDS[$i]}" "$RULES" > "$WORK/$m/rules/nvidia-gpu/nvidia-dcgm-exporter.yml"
  if cmp -s "$RULES" "$WORK/$m/rules/nvidia-gpu/nvidia-dcgm-exporter.yml"; then
    echo "=== $m: MUTATION DID NOT APPLY -> FAIL"; continue
  fi
  echo "=== $m: ${SEDS[$i]}"
  diff "$RULES" "$WORK/$m/rules/nvidia-gpu/nvidia-dcgm-exporter.yml"
  (cd "$WORK/$m" && "$PROMTOOL" test rules nvidia-dcgm-exporter.test.yml)
  rc=$?
  if [ $rc -ne 0 ]; then echo "=== $m: tests FAILED on mutant (exit $rc) -> CAUGHT"; caught=$((caught+1))
  else echo "=== $m: tests PASSED on mutant -> SURVIVED"; fi
done
echo "=== mutation summary: $caught/${#NAMES[@]} caught"
[ "$caught" -eq "${#NAMES[@]}" ]
