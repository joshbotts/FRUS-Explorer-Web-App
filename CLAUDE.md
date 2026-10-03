# FRUS Explorer Light

The self-hosted web edition of FRUS Explorer. `docs/PLAN.md` is the plan, `docs/SPEC.md` the specification, `docs/DEVLOG.md` the log of sessions, and `docs/prep/` holds notes for later sessions.

## Session rules

1. Start with `scripts/doctor`. Build and test only through `scripts/swift`, `npm --prefix web` and `docker compose`.
2. One session, one pull request, on the branch the session is given. Push before the session ends, and never push to `main`.
3. A session ends with CI green on its pull request and an entry in `docs/DEVLOG.md` that records what it delivered and names the next task.
4. Shared behaviour is compiled from the submodule, never reimplemented. A fix to a shared file is a pull request on `FRUS-Explorer`, labelled for Mac verification; a session never merges it.
5. The submodule pin moves only to a merged `FRUS-Explorer` commit, in a pull request of its own.
6. Never commit Mac exports, TEI beyond `fixtures/`, EmbeddingGemma, credentials, `.build/` or `node_modules/`.
7. Sessions never publish images. CI publishes from `main`.

`upstream/FRUS-Explorer/CLAUDE.md` is the Mac app's guide, and it governs only pull requests on that repository.

## Building

- `scripts/swift build`, `scripts/swift test`, `scripts/swift run FRUSLightServer`: SwiftPM in `swift:6.4-noble`, with output in `.build/linux`.
- `scripts/swift test list | cut -d. -f1 | sort | uniq -c` counts tests per target, as CI prints them.
- `scripts/swift --exec <command>` runs anything else in the same container.
- `scripts/compose-smoke` builds the image and runs the Compose smoke test, as CI does; `scripts/synthetic-export <file>` writes a small valid export.
