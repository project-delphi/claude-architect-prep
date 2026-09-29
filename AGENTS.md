# AGENTS.md

Guidance for coding agents working in this repo.

## Viewing target: one Mac, desktop browser

Everything in this repo is run and read on one Mac. That includes the GitHub
Pages site (https://project-delphi.github.io/claude-architect-prep/) and any
HTML pages or artifacts made from this repo's content.

- Don't design or test for phones, tablets or other devices. No mobile
  breakpoints, no phone-width screenshots or checks.
- Desktop browser widths are the only layout that matters.
- Code only needs to run on macOS, plus the site's GitHub Actions build, which
  renders the site on Ubuntu.
