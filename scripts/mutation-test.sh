#!/usr/bin/env bash
# Mutation check: each mutant is a deliberately broken copy of the rule file.
# The unit tests must FAIL on every mutant. A mutant that passes means the tests
# cannot see that kind of regression.
#
# Mutants (regenerated from the one-line descriptions in
# ~/krkn-gpu-work/dcgm-exporter-contrib/RESULTS.md; the original mutant files were not kept):
#   M1  `unless on (instance)` -> `and on (instance)`   (DCGMExporterNoGPUMetrics logic inverted)
#   M2  `== 0` -> `== 1`                                 (DCGMExporterDown fires on healthy targets)
#   M3  every `for: 5m` -> `for: 0m`                     (no pending period, short blips page)
#   M4  `absent(up{` -> `absent(dcgm_exporter_up{`       (wrong metric inside absent())
#
# Usage: mutation-test.sh <promtool> <rule file> <test file>
set -uo pipefail
PROMTOOL="$1"; RULES="$2"; TESTS="$3"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

declare -a NAMES=(M1 M2 M3 M4)
declare -a SEDS=(
  's/unless on (instance)/and on (instance)/'
  's/ == 0$/ == 1/'
  's/for: 5m/for: 0m/g'
  's/absent(up{/absent(dcgm_exporter_up{/'
)

caught=0
for i in "${!NAMES[@]}"; do
  m="${NAMES[$i]}"
  mkdir -p "$WORK/$m/rules" "$WORK/$m/tests"
  sed "${SEDS[$i]}" "$RULES" > "$WORK/$m/rules/$(basename "$RULES")"
  if cmp -s "$RULES" "$WORK/$m/rules/$(basename "$RULES")"; then
    echo "=== $m: MUTATION DID NOT APPLY (sed matched nothing) -> FAIL"; continue
  fi
  cp "$TESTS" "$WORK/$m/tests/$(basename "$TESTS")"
  echo "=== $m: ${SEDS[$i]}"
  diff "$RULES" "$WORK/$m/rules/$(basename "$RULES")"
  (cd "$WORK/$m/tests" && "$PROMTOOL" test rules "$(basename "$TESTS")")
  rc=$?
  if [ $rc -ne 0 ]; then echo "=== $m: tests FAILED on mutant (exit $rc) -> CAUGHT"; caught=$((caught+1))
  else echo "=== $m: tests PASSED on mutant -> SURVIVED (tests are blind to this)"; fi
done
echo "=== mutation summary: $caught/${#NAMES[@]} caught"
[ "$caught" -eq "${#NAMES[@]}" ]
