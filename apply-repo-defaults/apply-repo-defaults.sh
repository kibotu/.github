#!/usr/bin/env bash
#
# apply-repo-defaults.sh — apply your standard repository settings to one repo,
# or to every repository you own on GitHub.
#
# Settings come from .env next to this script (whitelisted KEY=value pairs,
# strictly boolean — the file is data, never executed).
#
# Archived repos are read-only on GitHub, so they are unarchived, updated, and
# re-archived automatically. If interrupted mid-batch, the script lists any
# repos it left unarchived.
#
# Usage:
#   ./apply-repo-defaults.sh                       # all repositories you own
#   ./apply-repo-defaults.sh OWNER/REPO            # one repo (URLs work too)
#   ./apply-repo-defaults.sh --dry-run [target]    # preview changes only
#
# Requires: bash, gh (authenticated), jq.

set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# ---------------------------------------------------------------- appearance

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m' DIM=$'\033[2m' GREEN=$'\033[32m' RED=$'\033[31m' YELLOW=$'\033[33m' RESET=$'\033[0m'
else
  BOLD='' DIM='' GREEN='' RED='' YELLOW='' RESET=''
fi

info() { printf '%s\n' "${DIM}$*${RESET}"; }
die()  { printf '%s%s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

onoff() { case $1 in true) printf on ;; false) printf off ;; *) printf '%s' "$1" ;; esac; }

# ------------------------------------------------------------- dependencies

for cmd in gh jq; do
  command -v "$cmd" > /dev/null || die "error: '$cmd' is required but not installed."
done
ACCOUNT=$(gh api user --jq .login 2> /dev/null) \
  || die "error: gh is not authenticated — run 'gh auth login' first."

# ------------------------------------------------------------ configuration

WIKI=false              ISSUES=true               PROJECTS=false
DISCUSSIONS=false       DELETE_BRANCH_ON_MERGE=true
SPONSORSHIPS=true       IMMUTABLE_RELEASES=true

ENV_FILE="$SCRIPT_DIR/.env"
ENV_SOURCE="(built-in defaults)"
if [ -f "$ENV_FILE" ]; then
  ENV_SOURCE="$ENV_FILE"
  while IFS= read -r line; do
    case $line in ''|\#*) continue ;; esac
    key=${line%%=*}; value=${line#*=}
    case $key in
      WIKI)                   WIKI=$value ;;
      ISSUES)                 ISSUES=$value ;;
      PROJECTS)               PROJECTS=$value ;;
      DISCUSSIONS)            DISCUSSIONS=$value ;;
      DELETE_BRANCH_ON_MERGE) DELETE_BRANCH_ON_MERGE=$value ;;
      SPONSORSHIPS)           SPONSORSHIPS=$value ;;
      IMMUTABLE_RELEASES)     IMMUTABLE_RELEASES=$value ;;
      *) printf '%swarning: ignoring unknown key "%s" in .env%s\n' "$YELLOW" "$key" "$RESET" >&2
         continue ;;
    esac
    case $value in true|false) ;;
      *) die "error: .env value for $key must be 'true' or 'false' (got: '$value')" ;;
    esac
  done < <(grep -vE '^[[:space:]]*$' "$ENV_FILE")
fi
export WIKI ISSUES PROJECTS DISCUSSIONS DELETE_BRANCH_ON_MERGE SPONSORSHIPS IMMUTABLE_RELEASES

LABELS=(wiki issues projects discussions "auto-delete branches" "sponsor button" "immutable releases")
WANTS=("$WIKI" "$ISSUES" "$PROJECTS" "$DISCUSSIONS" "$DELETE_BRANCH_ON_MERGE" "$SPONSORSHIPS" "$IMMUTABLE_RELEASES")

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

diff_summary() { # $1..$7 = current values -> human-readable change list ("" if compliant)
  local cur_vals=("$@") out="" i cur want
  for i in 0 1 2 3 4 5 6; do
    cur=$(onoff "${cur_vals[$i]}")
    want=$(onoff "${WANTS[$i]}")
    [ "$cur" = "$want" ] && continue
    out+="${out:+; }${LABELS[$i]} $cur → $want"
  done
  printf '%s' "$out"
}

current_state() { # OWNER NAME -> 7 tab-separated values
  local rest spon immu
  rest=$(gh api "repos/$1/$2" --jq '[.has_wiki,.has_issues,.has_projects,.has_discussions,.delete_branch_on_merge] | @tsv') || return 1
  spon=$(gh api graphql -f query='query($o:String!,$n:String!){repository(owner:$o,name:$n){hasSponsorshipsEnabled}}' \
          -f o="$1" -f n="$2" --jq '.data.repository.hasSponsorshipsEnabled') || return 1
  immu=$(gh api "repos/$1/$2/immutable-releases" --jq .enabled 2> /dev/null || echo false)
  printf '%s\t%s\t%s\n' "$rest" "$spon" "$immu"
}

apply_settings() { # OWNER/NAME — idempotent writes of every setting
  local full=$1 node_id
  retry 3 gh repo edit "$full" \
    --enable-wiki="$WIKI" \
    --enable-issues="$ISSUES" \
    --enable-projects="$PROJECTS" \
    --enable-discussions="$DISCUSSIONS" \
    --delete-branch-on-merge="$DELETE_BRANCH_ON_MERGE" || return 1
  node_id=$(retry 3 gh api "repos/$full" --jq .node_id) || return 1
  retry 3 gh api graphql -f query="mutation {
    updateRepository(input: {repositoryId: \"$node_id\", hasSponsorshipsEnabled: $SPONSORSHIPS}) {
      repository { nameWithOwner hasSponsorshipsEnabled }
    }
  }" > /dev/null || return 1
  if [ "$IMMUTABLE_RELEASES" = true ]; then
    retry 3 gh api -X PUT "repos/$full/immutable-releases" --silent || return 1
  else
    retry 3 gh api -X DELETE "repos/$full/immutable-releases" --silent 2> /dev/null || true
  fi
}

UNARCHIVED=$(mktemp)
REAPPLIED=$(mktemp)
cleanup() {
  if [ -s "$UNARCHIVED" ]; then
    printf '\n%sWARNING: interrupted — these repos were left UNARCHIVED:%s\n' "$YELLOW" "$RESET" >&2
    sed 's/^/  /' "$UNARCHIVED" >&2
  fi
  rm -f "$UNARCHIVED" "$REAPPLIED" "${LISTING:-}"
}
trap cleanup EXIT

apply_repo() { # OWNER NAME IS_ARCHIVED -> "<status>\t<details>\t<owner/name>"
  local owner=$1 name=$2 was_archived=$3 full="$1/$2" status changes cur

  cur=$(current_state "$owner" "$name") || { printf 'FAILED\tcould not read settings\t%s\n' "$full"; return 0; }
  changes=$(diff_summary $cur)

  if [ "$DRY_RUN" = true ]; then
    if [ -n "$changes" ]; then printf 'DRY\t%s\t%s\n' "$changes" "$full"
    else printf 'SKIP\talready at defaults\t%s\n' "$full"; fi
    return 0
  fi

  if [ -z "$changes" ]; then
    printf 'SKIP\talready at defaults\t%s\n' "$full"
    return 0
  fi

  if [ "$was_archived" = true ]; then
    retry 3 gh repo unarchive "$full" --yes > /dev/null || {
      printf 'FAILED\tunarchive\t%s\n' "$full"; return 0; }
    printf '%s\n' "$full" >> "$UNARCHIVED"
  fi

  status=ok
  apply_settings "$full" || status=FAILED

  if [ "$was_archived" = true ] && [ "$status" = ok ]; then
    if retry 3 gh repo archive "$full" --yes > /dev/null; then
      grep -Fvx -- "$full" "$UNARCHIVED" > "$REAPPLIED" 2> /dev/null || : > "$REAPPLIED"
      mv "$REAPPLIED" "$UNARCHIVED"
    else
      status=rearchive-failed
    fi
  fi

  printf '%s\t%s\t%s\n' "$status" "${changes:-no changes}" "$full"
}

format_results() { # pretty-print worker output, print summary at the end
  awk -F'\t' -v G="$GREEN" -v R="$RED" -v Y="$YELLOW" -v D="$DIM" -v N="$RESET" '
    $1 == "DRY"              { d++; printf "%s+%s %s\n    would change: %s\n", Y, N, $3, $2; next }
    $1 == "SKIP"             { s++; printf "%s=%s %s %s(%s)%s\n", D, N, $3, D, $2, N; next }
    $1 == "rearchive-failed" { rf++; printf "%s!%s %s — updated but NOT re-archived\n", Y, N, $3; next }
    $1 == "FAILED"           { f++; printf "%s✗%s %s (%s)\n", R, N, $3, $2; next }
                             { o++; if ($2 != "no changes") printf "%s✓%s %s %s[%s]%s\n", G, N, $3, D, $2, N
                                    else               printf "%s✓%s %s\n", G, N, $3 }
    END { printf "\nSummary: %d applied, %d skipped", o, s
          if (d  > 0) printf ", %d previewed", d
          if (rf > 0) printf ", %s%d NOT re-archived%s", Y, rf, N
          if (f  > 0) printf ", %s%d failed%s", R, f, N
          printf ".\n" }'
}

# --------------------------------------------------------------------- main

if [ "${1:-}" = "--worker" ]; then # internal: spawned via xargs by batch mode
  shift
  apply_repo "$@"
  exit 0
fi

DRY_RUN=${DRY_RUN:-false}
TARGET=all

while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=true ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*)       die "error: unknown option '$1'" ;;
    *)         TARGET=$1 ;;
  esac
  shift
done
export DRY_RUN

if [ "$TARGET" != all ]; then
  TARGET=$(printf '%s' "$TARGET" | sed -E 's#.*(github\.com[:/])##; s#\.git$##; s#/$##')
fi

printf '%s\n' "${BOLD}apply-repo-defaults${RESET}"
info "  account : $ACCOUNT"
info "  defaults: wiki=$(onoff "$WIKI")  issues=$(onoff "$ISSUES")  projects=$(onoff "$PROJECTS")  discussions=$(onoff "$DISCUSSIONS")"
info "            auto-delete branches=$(onoff "$DELETE_BRANCH_ON_MERGE")  sponsor button=$(onoff "$SPONSORSHIPS")  immutable releases=$(onoff "$IMMUTABLE_RELEASES")"
info "  source  : $ENV_SOURCE"
[ "$DRY_RUN" = true ] && info "  mode    : DRY RUN — nothing will be changed"

LISTING=$(mktemp)
if [ "$TARGET" = all ]; then
  QUERY='query($endCursor:String){viewer{repositories(first:100,after:$endCursor,affiliations:[OWNER]){pageInfo{hasNextPage endCursor}
         nodes{name owner{login} isArchived}}}}'
  gh api graphql --paginate -f query="$QUERY" --slurp \
    | jq -sr '[.[].[] | .data.viewer.repositories.nodes[]] | .[] | [.owner.login,.name,.isArchived] | @tsv' \
    > "$LISTING"
  info "  target  : all repositories owned by $ACCOUNT ($(wc -l < "$LISTING" | tr -d ' ')) — applying in parallel"
else
  [[ $TARGET =~ ^[^/]+/[^/]+$ ]] || die "error: can't parse '$TARGET' as OWNER/REPO"
  printf '%s\t%s\t%s\n' "${TARGET%/*}" "${TARGET#*/}" "$(gh api "repos/$TARGET" --jq .archived)" > "$LISTING"
  info "  target  : $TARGET"
fi
printf '\n'

cut -f1,2,3 "$LISTING" | xargs -P 8 -n 3 "$0" --worker | format_results
