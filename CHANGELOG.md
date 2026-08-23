# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-08-23

### Added

- Account-wide community health files: code of conduct, bug report and feature
  request issue forms (labelled `bug` / `enhancement`), pull request template,
  `FUNDING.yml`, Apache 2.0 license for this repository, and a `.gitignore`.
- `apply-repo-defaults/` — a script that applies standard repository settings
  (wiki, issues, projects, discussions, auto-delete head branches, sponsor
  button, immutable releases) to one repository or to every repository you own.
  Archived repositories are unarchived, updated, and re-archived automatically;
  runs are idempotent and support `--dry-run`. Defaults live in an editable
  `.env`.

[Unreleased]: https://github.com/kibotu/.github/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kibotu/.github/releases/tag/v1.0.0
