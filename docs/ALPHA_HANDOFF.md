# Playtest alpha handoff

Build: `0.15.0-alpha.1`
Build date: 2026-08-07
Engine: Godot 4.7.1 stable, GL Compatibility
Save shape: v16 (unchanged)

## Gate status

**Candidate artifacts exist, but the playtest alpha is not authorized yet.**

The documented automated suite baseline is green and the Mac/Windows exports
complete. The deterministic M15 policy report is red: all three policies reach
Earth zero around 233 minutes and miss the M14 receipt before the four-hour
ceiling. The uninterrupted fresh-save campaign and real-Windows smoke test are
also outstanding. These are alpha blockers, not known issues a tester should be
asked to work around.

## Artifacts

| Platform | Portable artifact | Size | SHA-256 |
|---|---|---:|---|
| macOS Universal (arm64 + x86_64) | `the-axeman/builds/alpha/the-axeman-0.15.0-alpha.1-macos-universal.zip` | 124 MB | `2e9a3b2a0e89bc1377d92bfda75a4eca7a7aac33d5e841c2e5f9ba50b633b788` |
| Windows x86_64 | `the-axeman/builds/alpha/the-axeman-0.15.0-alpha.1-windows-x86_64.zip` | 103 MB | `c65a97eb3d862db4d8584e4cad009e2df71d4e35bbf45ab1912a21d34ec39acd` |

Both archives pass integrity checks. The Mac executable is a Universal Mach-O
with arm64 and x86_64 slices and passes a local five-frame exported startup
smoke. The Windows executable is a PE32+ x86-64 GUI binary with its external
PCK. The binaries are intentionally unsigned; the Mac build is not notarized.

Build outputs are ignored by git. `export_presets.cfg`, version metadata and
these handoff documents are version-controlled source candidates. No source
checkpoint, commit, tag or push was created.

## Verified suite matrix

| Suite | Result |
|---|---:|
| M1 / M2 / M3 / M4 | 19/19 · 24/24 · 16/16 · 55/55 |
| M7A / M7B / M7C / M7D | 294/294 · 16/16 · 27/27 · 12/12 |
| Skill overhaul / XP delivery | 278/278 · 8/8 |
| M8 / M8 logistics | 122/122 · 19/19 |
| M9 / regional / M10 | 31/31 · 15/15 · 14/14 |
| M11 / M11B / M12 / M13 / M14 | 9/9 · 11/11 · 12/12 · 13/13 · 10/10 |
| Full campaign / M15 foundation | 9/9 · 29/29 |
| Tutorial / equipment / startup / slicer | 31/31 · 99/99 · 17/17 · 34/34 |
| M15 grant-free policies | **FAIL — 0/3 complete by 240 min** |

No documented acceptance suite produced an unexpected `FAIL`, script error,
crash or resource leak after stabilization. The grant-free policy report exits
non-zero by design while its acceptance condition remains unmet.

## Visual and package QA

The fresh yard, tutorial, XP, equipment, splitter, startup, Atlas, World Wood
Catalogue, Shop, launch and orbital-company capture sets were regenerated at
1280×720 under Compatibility. Buttons and active objectives remain reachable;
requirements are legible; no blocker-only presentation fix was required. Dense
late-game screens remain functional greybox and are not a UI-redesign gate.

The export filter excludes `core/tests/*` and `core/tools/*`. The MCP runtime
autoload remains packaged because the current production project configuration
references it; removing that repository tooling safely requires a separate
runtime/editor boundary change.

## Remaining authorization gate

1. Sam reviews the first failed pacing band and approves any placeholder value
   changes before they are made.
2. A grant-free public-path integration driver passes cautious, expected and
   optimized policies from identical fresh state.
3. One uninterrupted Godot 4.7.1 Compatibility campaign completes inside the
   two-to-four-hour target, includes real 120/240/360-second flights, and passes
   a post-completion v16 save/reload.
4. A clean Mac and real Windows machine each pass first launch, New Game,
   chopping, tutorial gates, save, quit, Load Game and continued progression.
5. Sam separately authorizes the source checkpoint and any commit/tag/push.

Commercial-release work and post-M14 content remain out of scope.
