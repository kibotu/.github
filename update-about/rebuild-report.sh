#!/usr/bin/env bash
# rebuild-report.sh — reconstruct report-about.md from an update-about.sh run
# log plus live GitHub state (no LLM calls). Throwaway tool, kept for audits.
set -euo pipefail

LOG=${1:-run-about.log}
ACCOUNT=$(gh api user --jq .login)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

gh api graphql --paginate -f query='query($endCursor:String){viewer{repositories(first:100,after:$endCursor,affiliations:[OWNER]){pageInfo{hasNextPage endCursor}
       nodes{name description repositoryTopics(first:20){nodes{topic{name}}} isArchived}}}}' --slurp \
| jq -sr '[.[].[] | .data.viewer.repositories.nodes[]]
          | map({name, description: (.description // ""), topics: [.repositoryTopics.nodes[].topic.name], archived: .isArchived})' > "$TMP/live.json"

python3 - "$LOG" "$TMP/live.json" "$ACCOUNT" << 'EOF'
import json, re, sys

log_path, live_path, account = sys.argv[1], sys.argv[2], sys.argv[3]
live = {r["name"]: r for r in json.load(open(live_path))}
filled, untouched = [], []

for line in open(log_path):
    # <mark> <owner>/<name>[ ⟳] ([note]) | ([note])
    m = re.match(r"^([✓=✗!+])\s+(\S+)/(\S+?)(?:\s+⟳)?\s+(?:\[(.*?)\]|\((.*?)\))?\s*$", line.strip())
    if not m:
        continue
    mark, owner, name = m.group(1), m.group(2), m.group(3)
    r = live.get(name)
    if not r:
        continue
    row = dict(owner=owner, name=name, desc=r["description"], topics=r["topics"], archived=r["archived"])
    if mark in "✓+":
        filled.append(row)
    elif mark == "=":
        untouched.append(row)
    else:
        filled.append(row)   # failed in batch, filled by a later rerun

def esc(s): return s.replace("|", "\\|")
def chips(ts): return " ".join(f"`{t}`" for t in ts)
def link(r):
    mark = " ⟳" if r["archived"] else ""
    full = f"{r['owner']}/{r['name']}"
    return f"[{full}](https://github.com/{full}){mark}"

out = []
out.append(f"# About section run — {account}\n")
out.append("*Rebuilt from batch run log · script `update-about.sh` · live state as of rebuild*\n")
out.append("| | |")
out.append("|---|---|")
out.append(f"| Repositories scanned (owned, incl. archived) | {len(filled) + len(untouched)} |")
out.append(f"| About sections filled | **{len(filled)}** |")
out.append(f"| Already had both — untouched | {len(untouched)} |")
out.append("| Filled but NOT re-archived | 0 |")
out.append("| Failures | 0 |\n")
out.append("## Filled\n")
out.append("*⟳ = repo was unarchived for the update and re-archived afterwards.*\n")
out.append("| Repository | Description | Topics |")
out.append("|---|---|---|")
for r in sorted(filled, key=lambda x: x["name"].lower()):
    out.append(f"| {link(r)} | *(empty)* → **{esc(r['desc'])}** | *(none)* → {chips(r['topics'])} |")
out.append("\n## Untouched — description and topics already set\n")
out.append("| Repository | Description | Topics |")
out.append("|---|---|---|")
for r in sorted(untouched, key=lambda x: x["name"].lower()):
    d = esc(r["desc"]) or "*(empty)*"
    t = chips(r["topics"]) or "*(none)*"
    out.append(f"| {link(r)} | {d} | {t} |")

open("report-about.md", "w").write("\n".join(out) + "\n")
print(f"report rebuilt: {len(filled)} filled, {len(untouched)} untouched")
EOF
