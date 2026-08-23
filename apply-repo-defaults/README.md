# apply-repo-defaults

One command to bring a GitHub repository — or every repository you own — in line
with your personal defaults: feature flags, merge behaviour, sponsor button,
and immutable releases.

```console
$ ./apply-repo-defaults.sh
apply-repo-defaults
  account : kibotu
  defaults: wiki=off  issues=on  projects=off  discussions=off
            auto-delete branches=on  sponsor button=on  immutable releases=on
  source  : /path/to/.env
  target  : all repositories owned by kibotu (321) — applying in parallel

✓ kibotu/ANR-Spy [issues off → on; sponsor button off → on]
✓ kibotu/AOHostels [wiki on → off; projects on → off; auto-delete branches off → on]
= kibotu/uCrop (already at defaults)

Summary: 309 applied, 12 skipped.
```

## What it configures

| Setting | Where | Default |
|---|---|---|
| Wiki | Settings → Features | off |
| Issues | Settings → Features | on |
| Projects | Settings → Features | off |
| Discussions | Settings → Features | off |
| Automatically delete head branches | Settings → Pull Requests | on |
| Sponsorships button | GraphQL `updateRepository` mutation | on |
| Release immutability | REST `PUT /repos/{owner}/{repo}/immutable-releases` | on |

Five of these ride `gh repo edit`. The last two exist because GitHub's REST API
silently ignores sponsorship fields and release immutability is a separate
endpoint — this script wires both up so you don't have to click through
Settings pages per repository.

## Requirements

- **bash** — macOS's stock bash 3.2 is fine
- **[gh](https://cli.github.com/)** — installed and authenticated (`gh auth login`);
  you need **admin access** on every repo it touches
- **jq**

## Setup

1. Put your defaults in `.env` next to the script:

   ```ini
   WIKI=false
   ISSUES=true
   PROJECTS=false
   DISCUSSIONS=false
   DELETE_BRANCH_ON_MERGE=true
   SPONSORSHIPS=true
   IMMUTABLE_RELEASES=true
   ```

   Only these seven keys are recognised, and values must be exactly `true` or
   `false` — anything else is rejected before anything runs. Unknown keys warn
   and are ignored. The file is parsed, never executed.

2. Preview, then apply:

   ```console
   $ ./apply-repo-defaults.sh --dry-run          # nothing is changed
   $ ./apply-repo-defaults.sh                    # all repos you own
   $ ./apply-repo-defaults.sh kibotu/uCrop       # one repo; full URLs work too
   ```

## Behaviour worth knowing

- **Idempotent.** Current state is read first; repositories already at your
  defaults are skipped without a single write. Safe to run repeatedly, e.g.
  from cron.
- **Archived repositories.** GitHub makes archived repos read-only, so the
  script unarchives each one, applies the defaults, and re-archives it —
  seconds of exposure per repo, archive state restored afterwards.
- **Interrupted runs.** If you Ctrl-C mid-batch, the script prints the list of
  repositories it left unarchived so nothing gets stranded silently.
- **Release immutability** only affects *future* releases, and a release that
  becomes immutable stays immutable even if you later disable the setting.
- **The sponsor button requires a GitHub Sponsors profile** for the owning
  account; GitHub rejects the mutation otherwise.
- Batch mode runs 8 workers in parallel and skips collaborator-owned
  repositories entirely (only repos you *own* are enumerated).

## Output legend

| Symbol | Meaning |
|---|---|
| `✓` | Applied — brackets list what changed |
| `=` | Skipped — already at your defaults |
| `+` | Dry-run preview — would change |
| `✗` | Failed — reason in parentheses; script continues with other repos |
| `!` | Updated but could not be re-archived — check manually |

## Exit codes

`0` on success (including runs where some repos were skipped). Non-zero when
preconditions fail (missing tools, bad `.env`, not authenticated).

## Notes

- The script never stores or echoes credentials; it uses your existing `gh`
  authentication.
- Rate limits: one full run costs roughly three API calls per unchanged repo
  and five per changed repo — well within authenticated limits for accounts of
  any ordinary size.
