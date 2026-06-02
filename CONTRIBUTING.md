# Contributing to dinv

Thanks for helping improve dinv! This is a small project, so the process is
light.

## Ways to contribute

- **Pull request** — fork (or branch, if you have write access), make your
  change, and open a PR against `master`. Good for most contributions.
- **Direct commit** — collaborators with write access can commit to `master`
  for small, self-contained changes.

## What every change must include

dinv ships its own version metadata, and three places must always agree:
`dinv.xml` (`version` attribute), `dinv.manifest` (`plugin_version`), and the
newest key in `dinv.changelog`. So each change should:

1. Add a `dinv.changelog` entry (newest first). Use `drlDbotChangeLogTypeFix`,
   `drlDbotChangeLogTypeNew`, or `drlDbotChangeLogTypeMisc`.
2. Bump the `version` attribute in `dinv.xml` (flat `3.XXXX`, +1 per change).
3. Bump `dinv.manifest`: `plugin_version`, every file you changed, and the
   meta files (`dinv.xml`, `dinv.changelog`, `dinv.manifest`).

Build tooling the plugin doesn't load at runtime (`build.py`, the GitHub
workflow) is intentionally **not** listed in the manifest.

Keep commits small and self-contained — one logical change each.

## Style

- Match the surrounding code. Lua modules use 2-space indentation and
  trailing `-- end <name>` comments on blocks.
- Verify your change in-game (MUSHclient) — there is no automated test suite,
  so live testing is the real gate.
- Optional static checks: `luac5.1 -p <file>.lua` to catch syntax errors, and
  `python build.py` to confirm the single-file build still assembles.

## Cutting a release

If your change is ready to ship, see **[RELEASE.md](RELEASE.md)** for the full,
step-by-step release process (tagging, notes, and the automated single-file
asset build). Anyone with write access can cut a release.

## Questions

Open an issue, or reach Rodarvus in-game on Aardwolf.
