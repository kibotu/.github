# `kibotu/.github`

Default community health files for the [`kibotu`](https://github.com/kibotu) account. A file here is
used by any `kibotu/*` repository that does not ship its own, so the policy lives in one place
instead of in fifty copies that drift apart.

This README describes the repository. It has no effect on the profile page — that is
[`kibotu/kibotu`](#kibotukibotu).

## What is here

| File | Purpose |
| --- | --- |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community code of conduct for every repository on the account |
| `README.md` | This file |
| `.gitignore` | macOS, Windows, JetBrains, and VS Code noise |

Everything else in the table below is a slot that is still empty. Add a file and it takes effect
immediately, across every repository, with no per-repository change.

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

Accepted locations are the repository root, `.github/`, and `docs/`. The two template directories are
the exception: they must live under `.github/`.

## How defaulting works

Four rules cover the behavior:

- **This repository must be public.** A private `.github` repository defaults nothing, even to other
  private repositories.
- **Resolution is per file.** A repository that ships its own `CONTRIBUTING.md` still inherits the
  code of conduct from here.
- **Template directories are all or nothing.** A repository with *any* file in its own
  `.github/ISSUE_TEMPLATE/` — a template, or only a `config.yml` — discards every default in this
  repository's `ISSUE_TEMPLATE/`.
- **A default is a UI overlay, not a file.** Defaults never appear in the file browser or the Git
  history of the consuming repository, and they are absent from its clones, packages, and downloads.

That last rule explains the one gap: **`LICENSE` cannot be defaulted.** A license has to travel with
the code, so each repository needs its own copy.

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
them can be defaulted from here unless the table above lists them.

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
- [Managing your profile README](https://docs.github.com/en/account-and-profile/how-tos/profile-customization/managing-your-profile-readme)
- [About GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages)
- [Personalizing GitHub Codespaces for your account](https://docs.github.com/en/codespaces/setting-your-user-preferences/personalizing-github-codespaces-for-your-account)
- [Customizing your organization's profile](https://docs.github.com/en/organizations/managing-organization-settings/customizing-your-organizations-profile)
