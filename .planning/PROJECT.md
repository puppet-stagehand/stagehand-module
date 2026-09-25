# stagehand (Puppet module)

The `stagehand` Puppet module (Forge: `stagehand-stagehand`): one namespace for every
ops task the Puppet Stagehand Console invokes, plus `stagehand::console_integration` —
the idempotent class that wires a puppetserver primary to the console. This repo is
stagehand's permanent home; `puppet-installer` vendors it directly by git URL and tag
(TOFU-pinned via `vendor.yaml`/`hack/vendor-modules.sh`, no Puppetfile/r10k).

**Core value:** Every console-invoked ops task (platform lock, ENC shim, trusted
external data, policy autosign, patching) is delivered as a well-tested, idempotent
Puppet class or task that `puppet-installer` and `puppet-console` can vendor and pin
with byte-identical, TOFU-verified integrity across releases.

## GSD adoption note

This repo had no GSD `.planning/` scaffolding before 2026-09-24 — a live PROG-02
violation flagged by the Stagehand Programme's Phase A work order
(`work-orders/A.md` dispatch item 7). This PROJECT.md and the accompanying
STATE.md exist to close that gap; they do not retroactively document prior
work (already shipped, tagged, and tracked under `puppet-console`'s own
numbered phases — see "Phase tracking" below).

## Phase tracking

This module does not run its own independent GSD roadmap. Feature work here is
tracked under `puppet-console`'s numbered phases (e.g. commit prefixes like
`999.12-03`) and releases are sequenced "in lockstep with installer 12.2" per
the Stagehand Programme's `ROADMAP.md` Phase A work-order targets. See
`puppet-console`'s own `.planning/ROADMAP.md` for the authoritative phase list
that drives changes here; `RELEASE.md` in this repo documents the tag/CI/release
process once a change is ready to ship.

## Key decisions

| Decision | Rationale | Date |
|---|---|---|
| No independent GSD roadmap; phase tracking stays in puppet-console | This module's work is entirely driven by console-side feature phases (ENC, autosign, patching, platform lock) — a parallel roadmap here would diverge from the real source of truth | 2026-09-24 |
