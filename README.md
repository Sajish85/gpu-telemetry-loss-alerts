# GPU telemetry-loss alerts for NVIDIA dcgm-exporter

Three Prometheus alert rules that fire when GPU telemetry stops arriving. They come with unit tests, mutation tests, and a worked example based on a chaos experiment (krkn Scenario C).

> **Testing disclosure:** validated with promtool unit and mutation tests on synthetic series; metric names checked against the exporter's default counters; not run against a live exporter or GPU.

Status: v1.0, published 19 November 2026. Zenodo DOI: https://doi.org/10.5281/zenodo.24360181. Author: Sajish Krishnan.

## Why these exist

dcgm-exporter can stop serving GPU data in two ways, and the usual alerts only catch one of them.

1. **The target is gone.** The pod crashed, the DaemonSet was deleted, or the scrape config broke. `up == 0` catches the first; `absent(up{…})` catches the case where no target exists at all.
2. **The target answers, but there are no GPU series in the response.** This is the case people miss. The exporter's `/health` handler returns 200 "OK" without checking DCGM collection (dcgm-exporter 4.9.0, `internal/pkg/server/server.go` lines 616–642, copy in `sources/server-4.9.0.go`). So `up` stays 1, probes stay green, and every GPU alert you have goes quiet because its input has disappeared.

| Alert | Expression (as shipped) | Catches |
|---|---|---|
| `DCGMExporterDown` | `up{job="dcgm-exporter", namespace="gpu-monitoring"} == 0` | an exporter target that is down |
| `DCGMExporterTargetsMissing` | `absent(up{job="dcgm-exporter", namespace="gpu-monitoring"})` | no exporter target at all |
| `DCGMExporterNoGPUMetrics` | `up{…} == 1 unless on (instance) DCGM_FI_DEV_GPU_UTIL_RATIO{…}` | target up, no GPU series |

All three use `for: 5m` and `severity: critical`.

## Targeted versions

| Component | Version | How it was used |
|---|---|---|
| dcgm-exporter | **4.9.0** (released 2026-11-06), main rule file | metric names read from `etc/default-counters.csv` at tag 4.9.0 (see METRIC-NAMES.md) |
| dcgm-exporter | **4.8.x and older**, legacy file | metric names read from `etc/default-counters.csv` at tag 4.8.4 |
| promtool (Prometheus) | **3.5.0** (darwin/arm64) | every recorded test run (TEST-OUTPUTS.md) |
| promtool 3.15.0 | used by awesome-prometheus-alerts CI | **not run here** (Docker daemon not running) |

## Files

| Path | What |
|---|---|
| `rules/dcgm-telemetry-loss.rules.yaml` | The rules, with dcgm-exporter 4.9.0+ names |
| `rules/dcgm-telemetry-loss.legacy-4.8.rules.yaml` | The same rules with 4.8.x names (`DCGM_FI_DEV_GPU_UTIL`) |
| `tests/rules_test.yaml`, `tests/rules_test.legacy-4.8.yaml` | 6 promtool unit cases each |
| `scripts/mutation-test.sh` | Builds 4 broken copies of the rules and checks that the tests fail on every one |
| `awesome-pr/` | The two-rule subset drafted for awesome-prometheus-alerts, with its own test file |
| `original/` | The files copied unchanged from the earlier local draft, kept for provenance |
| `sources/` | Copies of every upstream file the checks relied on |
| `METRIC-NAMES.md`, `TEST-OUTPUTS.md` | The name-port log and the raw test output |

## Run the tests (one command)

You need `promtool` on your PATH, or you can point the Makefile at a binary:

```bash
make test
```

```bash
make test PROMTOOL=/path/to/promtool
```

`make test` runs, in order:
1. `promtool check rules` on both rule files.
2. The 6 unit cases against the 4.9.0 file.
3. The 6 unit cases against the 4.8 file.
4. The 4-mutant check.

It prints `ALL CHECKS PASSED` only if every step succeeds. No GPU, exporter, cluster or Prometheus server is involved.

## Use the rules

**Plain Prometheus:** add the file to `rule_files:` in `prometheus.yml`. First edit `job=` and `namespace=` to match your scrape config. They assume the dcgm-exporter Helm chart installed as release `dcgm-exporter` in namespace `gpu-monitoring`.

**Prometheus Operator:** a PrometheusRule's `spec` has the same shape as a rule file. Put the file's `groups:` under `spec:` in a `monitoring.coreos.com/v1` `PrometheusRule`. Not tested with a real operator.

Known limits:
- **Nodes without GPUs.** `DCGMExporterDown` fires on nodes where the exporter is scheduled but can't start. Scope the DaemonSet to GPU nodes.
- **Custom metrics lists.** If you replace the default metrics list, `DCGMExporterNoGPUMetrics` needs a field your list still collects.
- **Unconfirmed on a real install:** whether `instance` matches between `up` and DCGM series on your setup, and how the rules behave with MIG.

## Worked example: krkn Scenario C (one exporter pod killed)

krkn-chaos/krkn PR #1673 (open) adds "Scenario C": it kills one dcgm-exporter pod and waits 120 s for the DaemonSet to recreate it. The point of the exercise is to find out whether the monitoring notices, and whether it should page.

The last unit case in `tests/rules_test.yaml` models that blackout with synthetic series, at one sample per minute:

| Minute | Old pod `10.0.0.1:9400` | New pod `10.0.0.7:9400` |
|---|---|---|
| 0–5 | `up=1`, GPU series present | not yet scraped |
| 6 | scrape fails: `up=0`, GPU series stale | not yet scraped |
| 7 onward | target gone (stale) | `up=1`, GPU series present |

Result at minute 15, as asserted by the test:
- **`DCGMExporterDown`: not firing.** `up == 0` held for one minute, shorter than `for: 5m`.
- **`DCGMExporterTargetsMissing`: not firing.** There was always at least one `up` series for the job.
- **`DCGMExporterNoGPUMetrics`: not firing.** The new pod served GPU series as soon as it was up.

This is the result you want: a routine pod replacement shouldn't wake anyone. It also shows why krkn's post-run alert check for Scenario C is set to `warning` rather than `error`. With these rules, "no page during a one-minute blackout" is the correct outcome, not a detection failure. To make the experiment *expect* a page, the blackout has to last longer than `for` (5 minutes here). In that case `DCGMExporterDown` or `DCGMExporterNoGPUMetrics` fires. The second, third and fifth unit cases cover those situations.

The other unit cases:
1. Healthy exporters: nothing fires.
2. One target down for good: `DCGMExporterDown` is pending at 4 min and firing at 6 min, only for that instance. It is not also reported as "no metrics".
3. No targets: `DCGMExporterTargetsMissing` fires.
4. Target up but no DCGM series: `DCGMExporterNoGPUMetrics` fires for that instance only.
5. GPU series go stale while the target stays up: fires after staleness plus `for`.

## Mutation check

`scripts/mutation-test.sh` builds four broken copies of the rule file. The tests must fail on each one:
- M1: `unless` → `and`
- M2: `== 0` → `== 1`
- M3: every `for: 5m` → `for: 0m`
- M4: a wrong metric inside `absent()`

All four are caught (TEST-OUTPUTS.md). The original mutant files from the earlier draft weren't kept, so these four were regenerated from the descriptions written down at the time.

## Licence

**CC BY 4.0** (Creative Commons Attribution 4.0 International, https://creativecommons.org/licenses/by/4.0/). It covers the files written for this project: the rules, tests, scripts, Makefile, `awesome-pr/` and the docs. This matches the licence of rule content in awesome-prometheus-alerts, whose LICENSE file puts "Alert rules and content (_data/rules.yml, dist/rules/, README.md)" under CC BY 4.0.

Files in `sources/` are unmodified copies of upstream files kept for checking, and they stay under their own licences. The NVIDIA dcgm-exporter files are Apache-2.0. The awesome-prometheus-alerts snapshots fall under that repo's dual licence (see its LICENSE file).

## How to cite

```bibtex
@misc{krishnan2026telemetryloss,
  author       = {Krishnan, Sajish},
  title        = {{GPU} Telemetry-Loss Alert Pack for {NVIDIA} dcgm-exporter},
  year         = {2026},
  publisher    = {Zenodo},
  doi          = {10.5281/zenodo.24360181},
  url          = {https://github.com/Sajish85/gpu-telemetry-loss-alerts},
  note         = {ORCID: 0009-0009-7561-9290. Licence: CC BY 4.0}
}
```
