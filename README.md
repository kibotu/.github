# `kibotu/.github`

![](docs/teaser.png)

Default community health files for the [`kibotu`](https://github.com/kibotu) account.

GitHub gives one repository name special power: `.github`. A file here applies to every `kibotu/*`
repository that does not ship its own copy. One code of conduct, one pull request template, one issue
form — not fifty copies that drift apart.

Two reasons this repository is public and documented:

- It is my working default. I mostly build Android, iOS, Kotlin, Swift, and agentic projects, so
  these files are tuned for small repositories with few maintainers and many drive-by issues.
- It is a worked example. Copy it, delete my name, and you have your own account-wide defaults in
  about ten minutes. [Set up your own](#set-up-your-own) has the steps.

I am still learning what belongs in here. Sections get added when a real issue or pull request shows
me that something was missing. Corrections are welcome.

## What is here

| File | Effect |
| --- | --- |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community standards for every repository on the account |
| [`.github/ISSUE_TEMPLATE/bug-report.yaml`](.github/ISSUE_TEMPLATE/bug-report.yaml) | Bug report form. Labels the issue `bug` |
| [`.github/ISSUE_TEMPLATE/feature-request.yaml`](.github/ISSUE_TEMPLATE/feature-request.yaml) | Feature request form. Labels the issue `enhancement` |
| [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md) | Pre-fills the pull request body: what changed, why, related issues |
| [`FUNDING.yml`](FUNDING.yml) | Renders the Sponsor button |
| [`LICENSE`](LICENSE) | Apache 2.0, for this repository only. A license cannot be defaulted — see [the rules](#the-rules) |
| [`.gitignore`](.gitignore) | macOS, Windows, JetBrains, and VS Code noise |

Every issue form keeps its fields optional. A half-filled report is better than no report.

Still empty, and deliberately so until I need them: `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`,
`GOVERNANCE.md`, `ISSUE_TEMPLATE/config.yml`, `DISCUSSION_TEMPLATE/`. Add one and it takes effect
across every repository at once, with no per-repository change.

## What can be defaulted

| File | Effect in the consuming repository |
| --- | --- |
| `CODE_OF_CONDUCT.md` | Linked from the repository sidebar and the new-issue flow |
| `CONTRIBUTING.md` | Linked when a person opens an issue or a pull request |
| `SECURITY.md` | Populates the Security tab |
| `SUPPORT.md` | Linked from the new-issue flow |
| `GOVERNANCE.md` | Linked from the repository sidebar |
| `FUNDING.yml` | Renders the Sponsor button |
| `PULL_REQUEST_TEMPLATE.md` | Pre-fills the pull request body |
| `ISSUE_TEMPLATE/`, `ISSUE_TEMPLATE/config.yml` | Issue templates and the template chooser |
| `DISCUSSION_TEMPLATE/` | Discussion category forms |

GitHub accepts three locations: the repository root, `.github/`, and `docs/`. The two template
directories are the exception. They must live under `.github/`.

## The rules

Four rules cover the behavior.

- **This repository must be public.** A private `.github` repository defaults nothing, not even to
  your other private repositories.
- **Resolution is per file.** A repository that ships its own `CONTRIBUTING.md` still inherits the
  code of conduct from here.
- **Template directories are all or nothing.** A repository with *any* file in its own
  `.github/ISSUE_TEMPLATE/` — a template, or only a `config.yml` — discards every default in this
  repository's `ISSUE_TEMPLATE/`.
- **A default is a UI overlay, not a file.** Defaults never appear in the file browser or the Git
  history of the consuming repository. They are absent from its clones, packages, and downloads.

The last rule explains the one real gap. **`LICENSE` cannot be defaulted.** A license has to travel
with the code, so each repository needs its own copy.

## Set up your own

1. Create a **public** repository named `.github` on your account. Nothing else works.
2. Add `CODE_OF_CONDUCT.md` first. It is the highest value per line, and GitHub links it from the
   sidebar of every repository at once.
3. Add `PULL_REQUEST_TEMPLATE.md` and `.github/ISSUE_TEMPLATE/*.yaml` next. Keep the fields optional.
   Required fields turn a report into a form to escape.
4. Verify from the outside. Open the Community Standards page of a consuming repository at
   `github.com/<you>/<repo>/community`, then start a new issue there. A default that does not show up
   is nearly always a name, a location, or the public rule.

Changes apply immediately. There is nothing to publish and no cache to wait for.

## Other special repository names

GitHub attaches behavior to a handful of repository *names*. Everything else is a normal repository.

### `kibotu/kibotu`

Profile README. `README.md` in the root of the default branch renders on
[github.com/kibotu](https://github.com/kibotu), above the pinned repositories.

It needs three things: the repository is public, the name matches the username exactly, and the file
is non-empty. Break any of the three and the profile falls back to no README, silently.

It supports a subset of HTML, including `<picture>` with `prefers-color-scheme`, so an image can have
a light and a dark variant:

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="dark.svg">
  <img src="light.svg" alt="">
</picture>
```

### `kibotu/kibotu.github.io`

GitHub Pages user site, served at [kibotu.github.io](https://kibotu.github.io) from the root of the
default branch. It needs no `gh-pages` branch and no `docs/` subdirectory — that convention belongs
to project sites, which are served under `/<repo>/`. The legacy `kibotu.github.com` name still
redirects here.

### `kibotu/dotfiles`

Codespaces personalization. If the repository is public, every new Codespace clones it and runs the
first of `install.sh`, `bootstrap.sh`, `setup.sh`, or `script/bootstrap` that it finds and that is
executable. With none of those present, the files are symlinked into `$HOME` instead.

### Organization-only names

None of these apply to `kibotu`, which is a user account. They are listed because the GitHub UI
advertises the first one to personal accounts too, where it does nothing.

- `<org>/.github` — `profile/README.md` renders as the public organization profile. This is the
  origin of the "initialize it with a README in the profile directory" hint. On a personal account
  the file is inert; use [`kibotu/kibotu`](#kibotukibotu).
- `<org>/.github-private` — `profile/README.md` renders as an organization profile that only members
  see.
- `<org>/.github` — `workflow-templates/` offers starter Actions workflows to the organization's
  repositories.

Community health file defaulting works identically for organizations.

### Not GitHub features

Third-party apps that read a fixed repository name. They are regularly mistaken for platform
behavior.

- `.allstar` — configuration for the OpenSSF Allstar app.
- `.dependabot` — organization-wide Dependabot v1 configuration. Deprecated; use a per-repository
  `.github/dependabot.yml`.

### Paths, not names

The adjacent set, for completeness: paths that are special *inside* an ordinary repository. None of
them can be defaulted from here unless [the table above](#what-can-be-defaulted) lists them.

- `.github/workflows/` — Actions workflows.
- `.github/dependabot.yml` — dependency update configuration.
- `.github/PULL_REQUEST_TEMPLATE/` — several pull request templates, selected with the `template=`
  query parameter.
- `.github/copilot-instructions.md` — repository-scoped Copilot instructions.
- `CODEOWNERS` — review assignment. Root, `.github/`, or `docs/`.
- `CITATION.cff` — renders the "Cite this repository" control.
- `.devcontainer/` — Codespaces and Dev Containers configuration.

## References

- [Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)
  — the authoritative doc for everything in [The rules](#the-rules)
- [Organization-wide community health files](https://github.blog/changelog/2019-02-21-organization-wide-community-health-files/)
  — the 2019 changelog that introduced the feature
- [Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
- [Managing your profile README](https://docs.github.com/en/account-and-profile/how-tos/profile-customization/managing-your-profile-readme)
- [About GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages)
- [Personalizing GitHub Codespaces for your account](https://docs.github.com/en/codespaces/setting-your-user-preferences/personalizing-github-codespaces-for-your-account)
- [Customizing your organization's profile](https://docs.github.com/en/organizations/managing-organization-settings/customizing-your-organizations-profile)

## Thanks

If this repository saved you an afternoon in the GitHub docs — or stopped one more stale copy of
`CODE_OF_CONDUCT.md` from drifting in a project you maintain — consider buying me a coffee.

[GitHub Sponsors](https://github.com/sponsors/kibotu) · [Buy Me a Coffee](https://buymeacoffee.com/kibotu) · [PayPal](https://paypal.me/janrabe/5)

Reusing the files is free and needs no attribution. Telling me what you changed is the part I like
most — it is how this repository gets better.

---

This README documents the repository. It does not render on my profile page; that is
[`kibotu/kibotu`](#kibotukibotu).
