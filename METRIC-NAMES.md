# Metric names: what was ported, and the source for each

Checked 16 Nov 2026 (Pacific) by reading files in NVIDIA/dcgm-exporter on GitHub. This was a static file read, not a live test. Copies of every file read are in `sources/`, and their SHA-256 hashes are in TEST-OUTPUTS.md.

## Summary

The rules use two metrics. **One name changed.** The other is not an exporter metric.

| Name in the original rules (4.8.x) | Name after port (4.9.0+) | Changed? | Where it comes from |
|---|---|---|---|
| `DCGM_FI_DEV_GPU_UTIL` | `DCGM_FI_DEV_GPU_UTIL_RATIO` | **Yes** | dcgm-exporter default counters (see below) |
| `up` | `up` | No | Created by Prometheus for every scrape target. Not an exporter metric, so there is nothing to check in the exporter. |

Nothing else was renamed. The selectors (`job="dcgm-exporter"`, `namespace="gpu-monitoring"`), alert names, `for` durations, severities and annotation text are unchanged. The one exception is that the metric name inside the `DCGMExporterNoGPUMetrics` description now reads `DCGM_FI_DEV_GPU_UTIL_RATIO`. The full diff is in TEST-OUTPUTS.md and was produced by `scripts/port_names.py`.

## Evidence for the rename

| What | Source (exact) | Finding |
|---|---|---|
| Latest release | GitHub API `repos/NVIDIA/dcgm-exporter/releases`, read 16 Nov 2026 | `4.9.0`, published 2026-11-06, not a prerelease, tag commit `4e663a526c`. Previous: `4.8.4` (2026-09-18, commit `fafd151148`). |
| 4.8.4 name | `https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/4.8.4/etc/default-counters.csv`, **line 23** → `sources/default-counters-4.8.4.csv` | `DCGM_FI_DEV_GPU_UTIL,      gauge, GPU utilization (in %).` |
| 4.9.0 name | `https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/4.9.0/etc/default-counters.csv`, **line 47** → `sources/default-counters-4.9.0.csv` | `DCGM_FI_DEV_GPU_UTIL_RATIO, gauge, GPU utilization as a ratio.` |
| Old name gone from 4.9.0 default list | The same 4.9.0 file | `DCGM_FI_DEV_GPU_UTIL` appears only as part of `DCGM_FI_DEV_GPU_UTIL_RATIO`. There is no standalone row, active or commented. |
| Helm chart uses that same file | `4.9.0/deployment/values.yaml` lines 41–47 → `sources/values-4.9.0.yaml` | `config.metrics[0].file: /etc/dcgm-exporter/chart/metrics/default-counters.csv`. In the repo tree, `deployment/files/default-counters.csv` is a symlink whose content is `../../etc/default-counters.csv`. Checked: the raw file holds only that path. |
| Release notes | GitHub release `4.9.0` body | "Rename the 23 default and profiling-preset fields that DCGM 4.7 deprecates to their new DCGM 4.7 names. Eleven of them also change unit: … utilization from a percentage to a 0 to 1 ratio …" |
| The awesome-list convention matches | `samber/awesome-prometheus-alerts` `_data/rules.yml` (snapshot `sources/awesome-rules-snapshot.yml`, master `a533dc44`, 14 Nov 2026), NVIDIA/dcgm-exporter section | "Metric names are the ones of dcgm-exporter 4.9.0+ (DCGM 4.7 field names)". Its underutilisation rule uses `DCGM_FI_DEV_GPU_UTIL_RATIO` and comments "4.8.x and older: DCGM_FI_DEV_GPU_UTIL, which is a percentage". |

## Unit change and what it means for these rules

- In 4.9.0 the field is a 0–1 ratio. In 4.8.4 it was a percentage.
- The rules test only whether the series **exists** (`unless on (instance) …`), never its value. So the unit change can't affect when they fire.
- In the test data I converted the sample values from percentages to ratios (35 → 0.35, 80 → 0.8, 50 → 0.5, 40 → 0.4), so the fixtures look like real 4.9.0 output. This doesn't change any test outcome.

## Things this check does NOT establish

- **Not verified live.** I can't confirm that a running 4.9.0 exporter emits `DCGM_FI_DEV_GPU_UTIL_RATIO` on every supported GPU, including MIG instances and GPUs where DCGM reports utilisation as unsupported. A GPU is needed for that.
- **Kubernetes per-pod series.** The 4.9.0 release notes say per-process GPU utilisation for pods is reported "under the new `DCGM_FI_DEV_GPU_UTIL_RATIO` and `DCGM_FI_DEV_FB_USED_BYTES` names as well as the old names". So on a 4.9.0 install with pod enrichment, the **old** name may still appear in some series. The ported rule ignores that. The legacy rule would match those series on 4.9.0, which is why it is shipped only for 4.8.x.
- **Custom metrics lists.** If someone replaces the default counters with a custom CSV that leaves out `DCGM_FI_DEV_GPU_UTIL_RATIO`, `DCGMExporterNoGPUMetrics` will fire on every healthy node. The README and the proposed awesome-list comment say to pick a field the list still collects.
- **The Helm chart values format changed in 4.9.0.** The release notes say so. The local Helm patch in `~/krkn-gpu-work/dcgm-exporter-contrib/` targets 4.8.4 values and was **not** re-ported tonight. Only the standalone rule files were.

## Variants shipped

- `rules/dcgm-telemetry-loss.rules.yaml`: 4.9.0+ names. This is the main file.
- `rules/dcgm-telemetry-loss.legacy-4.8.rules.yaml`: 4.8.x and older. Its content is byte-identical to `original/rules.yaml` plus a one-line header.
- Both files have their own 6-case test file, and both pass. A cross-check runs the 4.8-named rules against the 4.9-named series and **fails** on purpose, which shows the port matters (TEST-OUTPUTS.md).
