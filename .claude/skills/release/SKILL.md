---
name: release
description: Release a new version of the active_force gem. Use when asked to cut, prepare, or publish a release. Phase 1 (default) prepares the release PR; phase 2 (`publish`, after the PR is merged) builds and pushes the gem and creates the GitHub release.
argument-hint: "[version|publish] [--dry-run]"
---

# Releasing active_force

Two phases, split by the release PR being reviewed and merged. The argument is either a version or `publish`, never both.

- A version (`0.28.0`, no `v`) runs phase 1 with that version.
- No argument runs phase 1 and follows "Choosing the version" below.
- `publish` runs phase 2. It takes no version: it reads `VERSION` from `lib/active_force/version.rb` on an up-to-date `main`, which is the merged release.

`--dry-run` can be added to either form. See "Dry run" below.

## Dry run

With `--dry-run`, work through the phase as written but change nothing: describe what each step would do, with the real values filled in, and stop at the end. Print the plan as a numbered list in the same order as the steps, marking each as `would do`, `would skip (already done)` or `blocked (reason)`.

Only these commands are allowed:
- Read-only git: `git status`, `git fetch`, `git log`, `git diff`, `git show origin/main:<path>`, `git ls-remote --tags origin <tag>`. Do not switch branches or pull; read `main` through `origin/main` instead.
- Read-only GitHub: `gh pr list`, `gh pr view`, `gh release list`, `gh release view`, and the `generate-notes` API call (it only returns text).
- `gem list -r`.

Do not run `git switch`, `git pull`, `git commit`, `git push`, `gem build`, `gem push`, `gh pr create`, `gh release create`, or edit any file. If no version was given, still propose one and ask for it: the plan depends on it. Do not ask for the confirmations that precede `gem push` or `gh release create`; show what you would ask instead.

What to show:
- **Phase 1:** the chosen version, the branch name, the PR title, the exact `CHANGELOG.md` diff and `version.rb` change as they would be written, any `TBD` links, and the result of the already-released check.
- **Phase 2:** the version read from `origin/main`, whether the release PR is merged (and its number), the already-done check for rubygems, the GitHub release and the tag, the commands that would build and push, and the **final release notes** with the release PR's bullet removed.

End by saying nothing was changed, and that running the same command without `--dry-run` would do it for real.

## Choosing the version

Read the `## Not released` section of `CHANGELOG.md` and the current `ActiveForce::VERSION` in `lib/active_force/version.rb`.

- If there are no entries under `Not released`, stop and say there is nothing to release.
- Otherwise propose a bump (new feature or behavior change = minor, fixes only = patch, breaking change = major; this gem is 0.x so breaking changes are also a minor bump) with a one-line reason, and **ask the user to confirm or give a different version**. Never pick one silently.

## Phase 1: prepare the release PR

1. Require no modified or staged tracked files (`git status --untracked-files=no` is empty); untracked files don't matter. `git switch main && git pull`.
2. Check the `Not released` entries for placeholder links (`pull/TBD`). If any are found, list them and ask the user before continuing.
3. Refuse if `{version}` is already released: a git tag `{version}` exists, or `gem list -r -e active_force --all` includes it. `{version}` must also be greater than the current `VERSION`.
4. `git switch -c release_{version}`.
5. Set `VERSION = '{version}'` in `lib/active_force/version.rb`.
6. In `CHANGELOG.md`, insert a new `## {version}` heading directly under `## Not released`, so the existing entries fall under it, and leave `## Not released` at the top, empty. Result:

   ```
   # Changelog

   ## Not released

   ## {version}
   - ...entries...
   ```
7. Do not touch `Gemfile.lock` (gitignored) and never `git add` `*.gem` files. Stage only `version.rb` and `CHANGELOG.md`.
8. Commit as `Release {version}`, push, and open a PR titled `Release {version}`. **Do not use the Linear `KEY-N | TYPE | title` format for release PRs.** The body can be the changelog entries being released.
9. Report the PR URL and stop. Someone else approves and merges it. Do not merge it.

## Phase 2: publish (only after the release PR is merged)

Naming, matching past releases: the git tag is `{version}` (no `v`) and the GitHub release title is `v{version}`.

1. `git switch main && git pull`. Read `{version}` from `version.rb`.
2. Confirm the release PR is merged: `gh pr list --head release_{version} --state merged --json number,title`. If it isn't, stop and say so. This works after the branch is deleted. Keep the PR number for step 6.
3. **Check what is already done**, so a rerun resumes instead of failing partway. Report the result to the user, skip the steps that are done, and continue with the rest:
   - On rubygems: `gem list -r -e active_force --all` includes `{version}` -> skip build and push (steps 4-5).
   - GitHub release: `gh release view {version}` succeeds -> skip notes and release (steps 6-7). If it succeeds, tell the user the release already exists and give the link.
   - A tag `{version}` exists (`git ls-remote --tags origin {version}`) with no GitHub release: stop and ask the user. The tag may point at the wrong commit, so don't create a release on it unprompted.
   - If everything is done, say so and stop.
4. `gem build active_force.gemspec`.
5. **Ask for explicit confirmation, then** `gem push active_force-{version}.gem`. A push cannot be undone. If rubygems needs an MFA code, ask the user to run it themselves with `! gem push active_force-{version}.gem`.
6. Generate release notes and drop the release PR's own entry:

   ```
   gh api repos/{owner}/{repo}/releases/generate-notes \
     -f tag_name={version} -f previous_tag_name={previous_tag} -f target_commitish=main \
     --jq .body
   ```

   `{previous_tag}` is `gh release list --limit 1 --json tagName --jq '.[0].tagName'`. Remove the bullet that links to the release PR's number (from step 2); do not match on its title. Keep everything else, including the "Full Changelog" line.
7. Show the user the final notes and ask to confirm. Then:

   ```
   gh release create {version} --target main --title "v{version}" --notes-file <file>
   ```

   This creates the tag.
8. Report the rubygems and GitHub release links. Leave the built `.gem` file alone (gitignored).
