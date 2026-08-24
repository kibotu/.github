# update-about

One command to fill in the missing "About" section — description and topics —
of a GitHub repository, or of every repository you own. Each repo's essence is
distilled by one isolated LLM call (via [opencode](https://opencode.ai)), so
repositories never see each other's context.

```console
$ ./update-about.sh
update-about
  account : kibotu
  model   : opencode/x-preview-f-free
  rule    : fill gaps only — existing descriptions/topics are never overwritten

  target  : 321 repositories owned by kibotu (incl. archived)

= kibotu/.github (already set)
✓ kibotu/vapor ⟳ [description+topics]
✓ kibotu/Agrona [topics]

Summary: 264 filled, 57 skipped, 0 not-re-archived, 0 failed.
report: /path/to/report-about.md
```

## What it fills

| Field | Rule | Where written |
|---|---|---|
| Description | only when currently empty; ≤ 350 chars, plain text | `PATCH /repos/{owner}/{repo}` |
| Topics | only when there are none; 5–20, `[a-z0-9-]`, deduped | `PUT /repos/{owner}/{repo}/topics` |

The topics `PUT` replaces the whole list, so it is deliberately gated on the
repo having zero topics — existing descriptions and topics are never touched.

## Requirements

- **bash** — macOS's stock bash 3.2 is fine
- **[gh](https://cli.github.com/)** — installed and authenticated (`gh auth login`)
- **jq**
- **[opencode](https://opencode.ai)** with an available model; override with
  `MODEL=provider/model`, default is `opencode/x-preview-f-free` ("Ox Alpha Free")

## Usage

```console
$ ./update-about.sh --dry-run          # generate + preview, change nothing
$ ./update-about.sh                    # all repos you own
$ ./update-about.sh OWNER/REPO         # one repo; full URLs work too
```

A run writes `report-about.md` next to the script: per-repo before → after for
descriptions and topics, plus everything left untouched.

## Behaviour worth knowing

- **Fill-gaps-only.** Repos that already have both fields are skipped without
  a single write. Reruns are cheap and resume exactly where the last run
  stopped.
- **Archived repositories.** GitHub makes archived repos read-only, so the
  script unarchives each one, writes the missing fields, and re-archives it.
  If interrupted mid-batch, it prints any repo left unarchived so nothing gets
  stranded silently.
- **Dry run is dry.** In `--dry-run` mode the LLM still generates so you can
  review the copy, but no GitHub mutation call is made.
- **Isolated prompts.** One opencode invocation per repository; no other repo's
  content enters a prompt.
- **Runtime.** Roughly 20–40 s per repo that needs a fill (sequential loop);
  fully-set repos pass in about a second. A large first run is best launched
  detached: `nohup ./update-about.sh > run-about.log 2>&1 &`
- Model output is sanitized to GitHub's rules (length, charset, count) before
  anything is written; unusable output is retried, then reported as failed.

## Output legend

| Symbol | Meaning |
|---|---|
| `✓` | Filled — brackets list what was added |
| `=` | Skipped — already set |
| `+` | Dry-run preview — would fill |
| `⟳` | Repo was unarchived for the update and re-archived afterwards |
| `!` | Updated but could not be re-archived — check manually |
| `✗` | Failed — reason in parentheses; script continues |

## rebuild-report.sh

Reconstructs `report-about.md` from a saved run log plus live GitHub state —
no LLM calls. Useful when a later partial rerun overwrote the report of a big
batch:

```console
$ ./rebuild-report.sh run-about.log
report rebuilt: 264 filled, 57 untouched
```

## Notes

- The script never stores or echoes credentials; it uses your existing `gh`
  authentication and whatever model `opencode` is configured with.
