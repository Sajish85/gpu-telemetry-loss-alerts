"""Port the original rule file and tests from the dcgm-exporter 4.8.x metric
name to the 4.9.0+ name. Exactly one exporter metric is used by the rules:
  DCGM_FI_DEV_GPU_UTIL (4.8.4, percent)  ->  DCGM_FI_DEV_GPU_UTIL_RATIO (4.9.0, 0-1 ratio)
Sources: sources/default-counters-4.8.4.csv line 23, sources/default-counters-4.9.0.csv line 47.
Also writes the legacy (4.8.x) variant unchanged except for paths."""
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
OLD, NEW = "DCGM_FI_DEV_GPU_UTIL", "DCGM_FI_DEV_GPU_UTIL_RATIO"
rules = (root/"original/rules.yaml").read_text()
tests = (root/"original/rules_test.yaml").read_text()
assert NEW not in rules and rules.count(OLD) == 2, "unexpected original rule file"
(root/"rules/dcgm-telemetry-loss.rules.yaml").write_text(
    "# dcgm-exporter 4.9.0+ metric names. Ported from original/rules.yaml; see METRIC-NAMES.md.\n"
    + re.sub(rf"\b{OLD}\b", NEW, rules))
(root/"rules/dcgm-telemetry-loss.legacy-4.8.rules.yaml").write_text(
    "# dcgm-exporter 4.8.x and older metric names. Identical to original/rules.yaml.\n" + rules)
# Tests: rename the metric, convert sample values from percent to ratio (presence is what the
# rules test; the values only need to be realistic), and point rule_files at the ported file.
def pct_to_ratio(m):
    vals = m.group(2)
    vals = re.sub(r"(?<![\w.])(\d+)x", lambda v: f"{int(v.group(1))/100:g}x", vals)
    return m.group(1) + vals + m.group(3)
t = re.sub(rf"\b{OLD}\b", NEW, tests)
t = re.sub(r"(series: '"+NEW+r"\{[^']*\}'\n\s+values: ')([^']*)(')", pct_to_ratio, t)
t = t.replace("rule_files:\n  - rules.yaml", "rule_files:\n  - ../rules/dcgm-telemetry-loss.rules.yaml")
(root/"tests/rules_test.yaml").write_text(t)
lt = tests.replace("rule_files:\n  - rules.yaml", "rule_files:\n  - ../rules/dcgm-telemetry-loss.legacy-4.8.rules.yaml")
(root/"tests/rules_test.legacy-4.8.yaml").write_text(lt)
print("ported; NEW occurrences: rules", re.sub(rf"\b{OLD}\b", NEW, rules).count(NEW), "tests", t.count(NEW))
