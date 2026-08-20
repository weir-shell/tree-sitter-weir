#!/usr/bin/env bash
# The grammar's own gates [ts-split]: (1) the committed src/ is what
# grammar.js generates; (2) this grammar agrees with the targeted weir
# ref's grammar manifest; (3) that ref's .weir corpus parses with zero
# ERROR nodes — one recorded exception (README: Known nits).
# Run from the repo root; expects a weir checkout path as $1.
set -euo pipefail
WEIR="${1:?usage: ci/check.sh <path-to-weir-checkout>}"

# 1 — generate must be a no-op against the committed src/
npx --yes tree-sitter-cli@0.26.12 generate
if ! git diff --quiet -- src; then
    echo "FAIL: committed src/ differs from what grammar.js generates" >&2
    git diff --stat -- src >&2
    exit 1
fi
echo "ok: generate is clean against committed src/"

# 2 — the manifest agreement (within kinds + adapters + keywords)
python3 - "$WEIR" <<'PY'
import json, re, sys
weir = sys.argv[1]
m = json.load(open(f"{weir}/editors/grammar-manifest.json"))
g = open("grammar.js").read()

def alt(rx, label):
    mm = re.search(rx, g)
    if not mm:
        print(f"FAIL: cannot find the {label} rule in grammar.js"); sys.exit(1)
    return sorted(set(re.findall(r"[a-z]+", mm.group(1))))

wk = alt(r"within_kind: _ => choice\(([^)]+)\)", "within_kind")
if wk != m["withinKinds"]:
    print(f"FAIL: within kinds diverge: grammar={wk} manifest={m['withinKinds']}"); sys.exit(1)

ad = alt(r"choice\('to', 'from'\), [^,]+, choice\(([^)]+)\)", "adapter")
want = sorted(set(m["adapters"]["from"]) | set(m["adapters"]["to"]))
if ad != want:
    print(f"FAIL: adapters diverge: grammar={ad} manifest={want}"); sys.exit(1)

kw_m = re.search(r"keyword: _ =>\s*choice\(([^)]+)\)", g, re.S)
if not kw_m:
    print("FAIL: cannot find the keyword rule"); sys.exit(1)
kw = sorted(set(re.findall(r"'(\w+)'", kw_m.group(1))))
# the grammar carries booleans in their own rule; the manifest's
# keyword set minus true/false is the keyword-rule contract
want_kw = sorted(set(m["keywords"]) - {"true", "false"})
missing = [k for k in want_kw if k not in kw]
if missing:
    print(f"FAIL: keywords missing from the grammar: {missing}"); sys.exit(1)
print(f"ok: manifest agreement ({len(want_kw)} keywords, {wk} kinds, {want} adapters)")
PY

# 3 — the corpus, zero ERROR nodes (one recorded exception)
errs=0
allowed=0
for f in "$WEIR"/examples/*.weir "$WEIR"/tools/*.weir; do
    # the summary line repeats the first ERROR — count TREE nodes only
    # (the summary starts with the file path; tree lines are indented)
    out=$(npx --yes tree-sitter-cli@0.26.12 parse "$f" 2>/dev/null | grep -v "^/" | grep -c "(ERROR" || true)
    if [ "$out" -gt 0 ]; then
        if [ "$(basename "$f")" = "showcase.weir" ] && [ "$out" -le 1 ]; then
            allowed=$((allowed + out))   # the recorded {{literal braces}} nit
        else
            echo "ERROR nodes in $f: $out" >&2
            errs=$((errs + out))
        fi
    fi
done
[ "$errs" -eq 0 ] || { echo "FAIL: corpus has $errs unrecorded ERROR nodes" >&2; exit 1; }
echo "ok: corpus parses clean ($allowed recorded-nit node(s) tolerated)"
