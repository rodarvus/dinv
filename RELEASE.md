# Releasing dinv

This guide covers everything needed to cut a new dinv release. Anyone with
write access to the repo can follow it end to end — coordinating with the
maintainer first is courtesy, not a gate.

## The golden rule

Three places carry the version, and they must always agree:

- **`dinv.xml`** — the `version="3.XXXX"` attribute in the `<plugin>` tag
- **`dinv.manifest`** — the `plugin_version` field
- **`dinv.changelog`** — the newest `dbot.changelog[3.XXXX]` key (entries are
  listed newest-first)

If these three disagree, the in-plugin updater and the `dinv version` display
misbehave. Every release ends with all three equal.

## Version numbering

dinv uses a flat `3.XXXX` scheme. Increment by one for each change
(e.g. `3.0110` -> `3.0111`). There is no separate major/minor — every shipped
change gets the next number.

## 1. Every change must update version metadata

Before a release is even possible, each change you commit must include:

1. **Changelog entry** at the top of `dinv.changelog`:

   ```lua
   dbot.changelog[3.XXXX] =
   {
     { change = drlDbotChangeLogTypeFix,   -- or ...TypeNew / ...TypeMisc
       desc   = [[Short description of what changed and why.]]
     }
   }
   ```

   Types: `drlDbotChangeLogTypeFix` (bug fix), `drlDbotChangeLogTypeNew`
   (feature), `drlDbotChangeLogTypeMisc` (anything else).

2. **`dinv.xml`** — bump the `version` attribute to the new number.

3. **`dinv.manifest`** — bump:
   - `plugin_version`,
   - the entry for **every file you changed**, and
   - the three meta files: `dinv.xml`, `dinv.changelog`, `dinv.manifest`.

   Leave unchanged files at their existing versions. Build tooling that the
   plugin does not load at runtime (e.g. `build.py`, the GitHub workflow) is
   intentionally **not** listed in the manifest, so don't add it there.

Keep commits small and self-contained — one logical change each.

## 2. Pre-release verification

dinv has no automated test suite, so verification is static checks plus live
testing.

- **Syntax-check the Lua you changed** (needs Lua 5.1):

  ```
  luac5.1 -p dinv_dbot.lua      # repeat for each module you touched
  ```

- **Confirm the single-file build still assembles:**

  ```
  python build.py               # writes dinv_single.xml (gitignored)
  ```

  This catches concatenation/encoding problems before they reach users.

- **Live-test in MUSHclient.** Load the change in-game and exercise it. This
  is the real gate — never ship a change you have not seen work in the client.

- **Coherence check** — confirm the three versions match:

  ```
  grep 'version="3' dinv.xml
  grep plugin_version dinv.manifest
  head dinv.changelog
  ```

## 3. Cut the release

With the change committed and on `master`:

1. **Tag** (annotated):

   ```
   git tag -a v3.XXXX -m "dinv v3.XXXX - short description"
   ```

2. **Push** master and the tag:

   ```
   git push origin master
   git push origin v3.XXXX
   ```

3. **Write release notes.** Match the style of recent releases — prose with
   `##` sections, crediting contributors by name and PR link. Browse prior
   examples for tone:

   ```
   gh release list -R rodarvus/dinv
   gh release view v3.0110 -R rodarvus/dinv
   ```

4. **Create the release** (this publishes it immediately):

   ```
   gh release create v3.XXXX -R rodarvus/dinv \
     --title "dinv v3.XXXX - short description" \
     --notes-file notes.md --verify-tag
   ```

## 4. What happens automatically

When a release is **published**, the *Attach single-file build to release*
GitHub Actions workflow (`.github/workflows/build-single-file.yml`) checks out
the released tag, runs `build.py`, and attaches two assets to the release:

- `dinv_single.xml` — the one-file install
- `dinv.manifest` — so single-file installs can check the latest released
  version

You never build or upload these by hand.

## 5. After release

Confirm both assets attached:

```
gh release view v3.XXXX -R rodarvus/dinv --json assets --jq '.assets[].name'
```

You should see `dinv_single.xml` and `dinv.manifest`.

## Notes

- The **multi-file install is the recommended way to run dinv**. The
  single-file build is a convenience option and, as of v3.0110, can
  self-update from the latest release via `dinv update`.
- If a release ever ships without the assets, check the workflow run:
  `gh run list -R rodarvus/dinv --workflow=build-single-file.yml`.
