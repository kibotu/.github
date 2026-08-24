#!/usr/bin/env bash
#
# update-about.sh — fill in missing GitHub "About" sections (description +
# topics) on repositories you own, using an LLM to distill each repo's essence.
#
# Only fills gaps: a repo that already has a description keeps it, a repo that
# already has topics keeps them. Nothing is ever overwritten.
#
# Each repo is distilled by a separate, isolated LLM call (no cross-pollution).
#
# Archived repos are read-only on GitHub: they are unarchived, filled, and
# re-archived automatically. If interrupted mid-batch, the script lists any
# repos it left unarchived.
#
# Usage:
#   ./update-about.sh                       # every repo you own
#   ./update-about.sh OWNER/REPO            # one repo (URLs work too)
#   ./update-about.sh --dry-run [target]    # generate + preview, change nothing
#
# Requires: bash, gh (authenticated), jq, opencode.
# Output:   report-about.md + live progress.

set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

MODEL=${MODEL:-opencode/x-preview-f-free}   # "Ox Alpha Free"
DESC_MAX=350                                # GitHub hard limit
MAX_TOPICS=20                               # GitHub hard limit

# ---------------------------------------------------------------- appearance

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'
else
  BOLD='' DIM='' GREEN='' RED='' YELLOW='' RESET=''
fi

info() { printf '%s\n' "${DIM}$*${RESET}"; }
die()  { printf '%s%s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

# ------------------------------------------------------------- dependencies

for cmd in gh jq opencode; do
  command -v "$cmd" > /dev/null || die "error: '$cmd' is required but not installed."
done
ACCOUNT=$(gh api user --jq .login 2> /dev/null) \
  || die "error: gh is not authenticated — run 'gh auth login' first."

# ------------------------------------------------------------------- helpers

retry() { # retry <attempts> <cmd...>
  local attempts=$1 i=1
  shift
  until "$@"; do
    if [ "$i" -ge "$attempts" ]; then return 1; fi
    sleep "$((i * 2))"
    i=$((i + 1))
  done
}

# generate PROMPT -> "<description>\t<topics>" on stdout, nonzero if unusable.
# Strips ANSI + prose/code fences, validates shape, sanitizes to GitHub rules.
generate() {
  local resp json desc topics attempt
  for attempt in 1 2 3; do
    resp=$(opencode run --model "$MODEL" "$1" < /dev/null 2> /dev/null || true)
    resp=$(printf '%s' "$resp" | sed $'s/\x1b\\[[0-9;]*m//g')
    json=$(printf '%s' "$resp" | jq -RS 'capture("(?<j>(?s)\\{.*\\})").j | fromjson' 2> /dev/null || true)
    desc=$(jq -r '.description // ""' <<< "$json" 2> /dev/null || true)
    topics=$(jq -r '[.topics[]? | tostring | ascii_downcase
                      | gsub("[^a-z0-9]+"; "-") | gsub("^-+|-+$"; "")
                      | select(length >= 2 and length <= 50)]
                     | unique | .[0:'"$MAX_TOPICS"'] | join(",")' <<< "$json" 2> /dev/null || true)
    [ -n "$desc" ] && [ -n "$topics" ] && break
    sleep $((attempt * 3))
  done
  desc=$(printf '%s' "$desc" | tr '\t\n' '  ' | tr -s ' ')
  if [ "${#desc}" -gt "$DESC_MAX" ]; then desc=${desc:0:"$DESC_MAX"}; desc=${desc%\ *}; fi
  [ -n "$desc" ] && [ -n "$topics" ] || return 1
  printf '%s\t%s\n' "$desc" "$topics"
}

UNARCHIVED=$(mktemp)   # repos currently left unarchived (interrupt safety)
cleanup() {
  if [ -s "$UNARCHIVED" ]; then
    printf '\n%sWARNING: interrupted — these repos were left UNARCHIVED:%s\n' "$YELLOW" "$RESET" >&2
    sed 's/^/  /' "$UNARCHIVED" >&2
  fi
  rm -f "$UNARCHIVED"
}
trap cleanup EXIT

process_repo() { # OWNER NAME -> appends one TSV line to RESULTS
  local owner=$1 name=$2 full="$1/$2" repo_json out desc topics status note was_archived rearchived

  repo_json=$(gh api "repos/$full") || {
    printf 'FAIL\t%s\tcould not read repo\t\t\t\t\t0\n' "$full"; return 0; }
  old_desc=$(jq -r '.description // ""' <<< "$repo_json")
  old_topics=$(jq -r '(.topics // []) | join(",")' <<< "$repo_json")
  stars=$(jq -r '.stargazers_count' <<< "$repo_json")
  lang=$(jq -r '.language // ""' <<< "$repo_json")
  was_archived=$(jq -r '.archived' <<< "$repo_json")
  has_desc=$([ -n "$old_desc" ] && echo 1 || echo 0)
  has_topics=$([ -n "$old_topics" ] && echo 1 || echo 0)

  if [ "$has_desc" = 1 ] && [ "$has_topics" = 1 ]; then
    printf 'SKIP\t%s\talready set\t%s\t%s\t\t\t%s\n' "$full" "$old_desc" "$old_topics" "$was_archived"
    return 0
  fi

  readme=$(gh api "repos/$full/readme" -H "Accept: application/vnd.github.raw" 2> /dev/null || true)
  readme=${readme:0:4000}
  if [ -n "$readme" ]; then
    ctx="README excerpt:
$readme"
  else
    ctx="No README. Top-level files: $(gh api "repos/$full/contents" --jq '[.[].name] | join(", ")' 2> /dev/null || echo unknown)"
  fi

  out=$(generate "You are writing the GitHub \"About\" section for one repository.

Repository: $full
Primary language: ${lang:-unknown}
Stars: ${stars:-0}
Current description: ${old_desc:-none}
Current topics: ${old_topics:-none}

$ctx

Task:
- description: the essence of this repository in 1-2 short sentences. Engaging
  and curious in tone, humble, positive. Plain text only — no markdown, no
  surrounding quotes, no emoji. Hard limit: $DESC_MAX characters.
- topics: 5-$MAX_TOPICS GitHub repository topics that fit the project precisely
  AND reach its target audience (what people searching for such a tool would
  type). Lowercase letters, digits, single hyphens only.

Reply with ONLY valid JSON in exactly this shape, nothing else:
{\"description\": \"...\", \"topics\": [\"topic-one\", \"topic-two\"]}") || {
    printf 'FAIL\t%s\tLLM produced no usable output\t%s\t%s\t\t\t%s\n' \
      "$full" "$old_desc" "$old_topics" "$was_archived"; return 0; }
  IFS=$'\t' read -r desc topics <<< "$out"

  status=ok
  note=""
  write=$([ "$DRY_RUN" = true ] && echo 0 || echo 1)   # dry run: generate, never mutate
  if [ "$has_desc" = 0 ]; then note="description"; fi
  if [ "$has_topics" = 0 ]; then note="${note:+$note+}topics"; fi
  rearchived=0

  if [ "$write" = 1 ]; then
    # archived repos are read-only — lift, write, re-archive
    if [ "$was_archived" = true ]; then
      retry 3 gh repo unarchive "$full" --yes > /dev/null || {
        printf 'FAIL\t%s\tunarchive failed\t%s\t%s\t\t\ttrue\n' "$full" "$old_desc" "$old_topics"; return 0; }
      printf '%s\n' "$full" >> "$UNARCHIVED"
    fi

    if [ "$has_desc" = 0 ]; then
      gh api -X PATCH "repos/$full" -f description="$desc" --silent > /dev/null \
        || { status=fail; note="${note} write failed"; }
    fi
    if [ "$has_topics" = 0 ] && [ "$status" = ok ]; then
      # safe: only called when the repo had zero topics, so nothing is clobbered
      gh api -X PUT "repos/$full/topics" --silent --input - \
        <<< "$(jq -cn --arg t "$topics" '{names: ($t | split(","))}')" > /dev/null \
        || { status=fail; note="${note:+$note, }topics write failed"; }
    fi

    if [ "$was_archived" = true ]; then
      if retry 3 gh repo archive "$full" --yes > /dev/null; then
        rearchived=1
        tmp=$(mktemp); grep -Fvx -- "$full" "$UNARCHIVED" > "$tmp" || : > "$tmp"
        mv "$tmp" "$UNARCHIVED"
      elif [ "$status" = ok ]; then
        status=rfail; note="updated but NOT re-archived"
      fi
    fi
    [ "$DRY_RUN" = true ] || sleep 2   # be gentle with the free tier
  fi

  if [ "$status" = fail ]; then
    printf 'FAIL\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$full" "$note" "$old_desc" "$old_topics" "$desc" "$topics" "$was_archived"
  elif [ "$status" = rfail ]; then
    printf 'RFAIL\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$full" "$note" "$old_desc" "$old_topics" "$desc" "$topics" "$was_archived"
  else
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$([ "$DRY_RUN" = true ] && echo DRY || echo UPD)" \
      "$full" "$note" "$old_desc" "$old_topics" "$desc" "$topics" "$was_archived"
  fi
}

# --------------------------------------------------------------------- main

DRY_RUN=false TARGET=all
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=true ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*)       die "error: unknown option '$1'" ;;
    *)         TARGET=$1 ;;
  esac
  shift
done

if [ "$TARGET" != all ]; then
  TARGET=$(printf '%s' "$TARGET" | sed -E 's#.*(github\.com[:/])##; s#\.git$##; s#/$##')
  [[ $TARGET =~ ^[^/]+/[^/]+$ ]] || die "error: can't parse '$TARGET' as OWNER/REPO"
  gh api "repos/$TARGET" --jq .archived > /dev/null 2>&1 || die "error: cannot access $TARGET"
fi

RESULTS=$(mktemp)
trap 'rm -f "$RESULTS"; cleanup' EXIT

printf '%s\n' "${BOLD}update-about${RESET}"
info "  account : $ACCOUNT"
info "  model   : $MODEL"
info "  rule    : fill gaps only — existing descriptions/topics are never overwritten"
[ "$DRY_RUN" = true ] && info "  mode    : DRY RUN — nothing will be changed"
printf '\n'

LISTING=$(mktemp)
if [ "$TARGET" = all ]; then
  QUERY='query($endCursor:String){viewer{repositories(first:100,after:$endCursor,affiliations:[OWNER]){pageInfo{hasNextPage endCursor}
         nodes{name owner{login} isArchived}}}}'
  gh api graphql --paginate -f query="$QUERY" --slurp \
    | jq -sr '[.[].[] | .data.viewer.repositories.nodes[]]
              | sort_by(.name) | .[] | [.owner.login,.name] | @tsv' > "$LISTING"
else
  printf '%s\n' "$TARGET" | tr '/' '\t' > "$LISTING"
fi
info "  target  : $(wc -l < "$LISTING" | tr -d ' ') repositories owned by $ACCOUNT (incl. archived)"
printf '\n'

while IFS=$'\t' read -ru 3 owner name; do
  [ -n "$name" ] || continue
  process_repo "$owner" "$name" >> "$RESULTS"
  line=$(tail -n 1 "$RESULTS")
  IFS=$'\t' read -r st full _ <<< "$line"
  a=$([ "$(cut -f8 <<< "$line")" = true ] && printf ' %s⟳%s' "$DIM" "$RESET" || printf '')
  case $st in
    UPD)   printf '%s✓%s %s%s %s[%s]%s\n' "$GREEN" "$RESET" "$full" "$a" "$DIM" "$(cut -f3 <<< "$line")" "$RESET" ;;
    DRY)   printf '%s+%s %s%s %s(would fill: %s)%s\n' "$YELLOW" "$RESET" "$full" "$a" "$DIM" "$(cut -f3 <<< "$line")" "$RESET" ;;
    SKIP)  printf '%s=%s %s%s %s(already set)%s\n' "$DIM" "$RESET" "$full" "$a" "$DIM" "$RESET" ;;
    RFAIL) printf '%s!%s %s %s— updated but NOT re-archived%s\n' "$YELLOW" "$RESET" "$full" "$DIM" "$RESET" ;;
    FAIL)  printf '%s✗%s %s %s(%s)%s\n' "$RED" "$RESET" "$full" "$DIM" "$(cut -f3 <<< "$line")" "$RESET" ;;
  esac
done 3< "$LISTING"
rm -f "$LISTING"

# ------------------------------------------------------------------- report

REPORT="$SCRIPT_DIR/report-about.md"
{
  printf '# About section run — %s\n\n' "$ACCOUNT"
  printf '*Generated %s · model `%s` · script `update-about.sh`%s*\n\n' \
    "$(date '+%Y-%m-%d %H:%M')" "$MODEL" "$([ "$DRY_RUN" = true ] && echo ' · DRY RUN — nothing written' || true)"

  awk -F'\t' '
    $1=="UPD" { u++ } $1=="DRY" { d++ } $1=="SKIP" { s++ } $1=="FAIL" { f++ } $1=="RFAIL" { rf++ }
    END {
      n = u + d + s + f + rf
      b = (rf > 0 ? "**" : "")
      printf "| | |\n|---|---|\n"
      printf "| Repositories scanned (owned, incl. archived) | %d |\n", n
      printf "| About sections filled | **%d** |\n", u + d
      printf "| Already had both — untouched | %d |\n", s
      printf "| Filled but NOT re-archived | %s%d%s |\n", b, rf, b
      printf "| Failures | %d |\n", f
    }' "$RESULTS"

  printf '\n## Filled\n\n'
  printf '*⟳ = repo was unarchived for the update and re-archived afterwards.*\n\n'
  printf '| Repository | Description | Topics |\n|---|---|---|\n'
  awk -F'\t' '
    ($1 == "UPD" || $1 == "DRY") {
      url = "https://github.com/" $2
      mark = ($8 == "true" ? " ⟳" : "")
      tag  = ($1 == "DRY" ? " *(dry run)*" : "")
      dafter  = "**" esc($6) "**"
      tafter  = chips($7)
      dcell = ($4 == "" ? "*(empty)* → " dafter : esc($4) " *(kept)*")
      tcell = ($5 == "" ? "*(none)* → " tafter : chips($5) " *(kept)*")
      printf "| [%s](%s)%s%s | %s | %s |\n", $2, url, mark, tag, dcell, tcell
    }
    function esc(s) { gsub(/\|/, "\\|", s); return s }
    function chips(s,  out, a, i) {
      out = ""; split(s, a, ",")
      for (i in a) out = out "`" a[i] "` "
      return out
    }' "$RESULTS"

  if grep -q '^SKIP' "$RESULTS"; then
    printf '\n## Untouched — description and topics already set\n\n'
    printf '| Repository | Description | Topics |\n|---|---|---|\n'
    awk -F'\t' '$1 == "SKIP" {
      url = "https://github.com/" $2
      printf "| [%s](%s) | %s | %s |\n", $2, url, before($4), before($5)
    }
    function before(s) { if (s == "") return "*(empty)*"; gsub(/\|/, "\\|", s); return s }
    ' "$RESULTS"
  fi

  if grep -q '^RFAIL' "$RESULTS"; then
    printf '\n## Updated but NOT re-archived\n\n'
    awk -F'\t' '$1 == "RFAIL" { printf "- [%s](https://github.com/%s)\n", $2, $2 }' "$RESULTS"
  fi

  if grep -q '^FAIL' "$RESULTS"; then
    printf '\n## Failed\n\n| Repository | Reason |\n|---|---|\n'
    awk -F'\t' '$1 == "FAIL" { printf "| [%s](https://github.com/%s) | %s |\n", $2, $2, $3 }' "$RESULTS"
  fi
} > "$REPORT"

printf '\nSummary: '
awk -F'\t' '$1=="UPD"{u++} $1=="DRY"{d++} $1=="SKIP"{s++} $1=="FAIL"{f++} $1=="RFAIL"{rf++}
  END { printf "%d filled, %d skipped, %d not-re-archived, %d failed.\n", u+d, s, rf, f }' "$RESULTS"
if [ "$DRY_RUN" = true ]; then info "(dry run — nothing was written)"; fi
info "report: $REPORT"
