"""Emulate awesome-prometheus-alerts' test/generate.sh for the NVIDIA dcgm-exporter
section, with the proposed rules inserted, so the PR's test file can be run locally.

Differences from their toolchain (stated, not hidden): their script uses mikefarah/yq
to turn _data/rules.yml into JSON and liquid-cli (Ruby) to render dist/template.yml.
This script uses PyYAML and python-liquid instead. Output is the generated rule file
test/rules/nvidia-gpu/nvidia-dcgm-exporter.yml under <out>.

Usage: render_awesome.py <rules snapshot> <template snapshot> <snippet> <out dir>
"""
import sys, pathlib, yaml
from liquid import parse

snap, tmpl, snippet, out = (pathlib.Path(p) for p in sys.argv[1:5])
data = yaml.safe_load(snap.read_text())
# The snippet is a YAML list fragment, indented as it would sit in rules.yml.
new_rules = yaml.safe_load("\n".join(l[14:] if l.startswith(" " * 14) else l
                                     for l in snippet.read_text().splitlines()
                                     if not l.strip().startswith("#")))
assert isinstance(new_rules, list) and len(new_rules) == 2, new_rules

found = None
for group in data["groups"]:
    for service in group["services"]:
        if service["name"] == "NVIDIA GPU":
            for exporter in service["exporters"]:
                if exporter.get("slug") == "nvidia-dcgm-exporter":
                    found = (service, exporter)
assert found, "NVIDIA GPU / nvidia-dcgm-exporter section not found in snapshot"
service, exporter = found
names = [r["name"] for r in exporter["rules"]]
assert not any("DCGM exporter" in n for n in names), "rules already present upstream?"
exporter["rules"] = new_rules + exporter["rules"]

subdir = out / "test/rules" / "-".join(service["name"].lower().split(" "))
subdir.mkdir(parents=True, exist_ok=True)
rendered = parse(tmpl.read_text()).render(exporter)  # liquid-cli passes the exporter JSON as the context
(subdir / f"{exporter['slug']}.yml").write_text(rendered)
print(subdir / f"{exporter['slug']}.yml")
print("rules in rendered file:", len(exporter["rules"]))
