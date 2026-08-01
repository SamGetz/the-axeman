# SETUP — getting The Axeman running on another machine

Everything the game needs is in this repository. There is no package manager
step, no dependency to fetch and no third-party plugin to install — the Godot
project is native nodes and GDScript only, and the addon it does use
(`godot_mcp`) is committed alongside the rest.

What is **not** in the repository, and what you therefore have to supply on a
new machine, is exactly three things: the engine binary, the import cache, and
your save file.

---

## 1. Install the engine

**Godot 4.7.1 stable, standard build (NOT the .NET/Mono build).** The project is
pure GDScript; the .NET build is a different binary with a different startup
path and there is no reason to use it here.

Get it from <https://godotengine.org/download> or the release tag directly at
<https://github.com/godotengine/godot/releases> (tag `4.7.1-stable`). On Windows
the file is `Godot_v4.7.1-stable_win64.exe`.

Godot ships as a single portable executable — put it wherever you like. On the
desktop machine it lives at `C:\Users\Sam\Desktop\Godot_v4.7.1-stable_win64.exe`,
which is the path CLAUDE.md quotes. **That path is that machine's, not the
project's.** Nothing in the repo reads it; it is only ever typed on a command
line.

The version matters. `project.godot` declares
`config/features=PackedStringArray("4.7", "GL Compatibility")`, and opening the
project in an older Godot will refuse or downgrade, while a newer one may
silently rewrite resource files on save.

### Make the path easy to type

Every command below assumes a `GODOT` variable pointing at the binary. Set it
once per shell:

```bash
export GODOT="/c/Users/Sam/Desktop/Godot_v4.7.1-stable_win64.exe"
```

```bash
$env:GODOT = "C:\Users\Sam\Desktop\Godot_v4.7.1-stable_win64.exe"
```

(The first is for the Git Bash shell, the second for PowerShell. Adjust the path
to wherever you actually put the binary on that machine.)

---

## 2. Clone the repository

```bash
git clone <your-remote-url> the_axeman
```

The repo root is the clone — `CLAUDE.md`, `AGENTS.md`, the `handoff/` pack,
`images/` and `maya_working/` all sit at the top level, and **the Godot project
is the `the-axeman/` subfolder inside it.** That distinction has cost this
project real time before; see the trap in section 5.

The clone is roughly 160 MB of working tree and 130 MB of history, dominated by
the FBX logs and the source PNGs. That is well inside GitHub's limits — the
largest single file is a 4.7 MB birch log — so **Git LFS is not needed and is
not configured.** If a future art drop lands a file over about 50 MB, revisit
that decision before committing it, not after.

---

## 3. Build the import cache — do this before anything else

`the-axeman/.godot/` is gitignored. It is 233 MB of engine-generated import
artifacts, and committing it would be both enormous and wrong — it is derived
data keyed to the exact engine build. A fresh clone therefore has **no imported
assets at all**: every FBX and PNG is raw source until Godot converts it.

Run the import once, from inside the Godot project folder:

```bash
cd the-axeman && "$GODOT" --headless --path . --import
```

This takes a few minutes on the first run (there are 40-odd meshes and textures)
and rebuilds `.godot/` from scratch. Until it finishes, **every scene will fail
to load and every test suite will report nonsense**, because the resources they
reference do not exist yet in importable form.

Rerun it whenever a new `class_name` is added, too — a headless run does not
refresh `.godot/global_script_class_cache.cfg` on its own, so a brand-new global
class reads as "Identifier not declared" everywhere it is used until you do.

---

## 4. Verify the checkout

Run the suites. These are the same commands CLAUDE.md lists, and the expected
results are the ones recorded there as of 2026-08-01. **Run all of them from
inside `the-axeman/`**, never from the repo root.

```bash
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m1_acceptance.tscn
```

```bash
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m2_acceptance.tscn
```

```bash
"$GODOT" --headless --path . --quit-after 900 res://core/tests/m3_acceptance.tscn
```

```bash
"$GODOT" --headless --path . --quit-after 8000 res://core/tests/m4_acceptance.tscn
```

```bash
"$GODOT" --headless --path . --quit-after 8000 res://core/tests/m7a_acceptance.tscn
```

```bash
"$GODOT" --headless --path . -s res://core/tools/test_slicer.gd
```

Expected: M1 21/21, M2 24/24, M3 16/16, M4 42/42, M7A 139/139, slicer 34/34.

Two of them will not behave headless, by design:

- **`pile_smoke` must run NON-headless.** Its last check waits out the pile
  animation, which runs on a real-time clock that uncapped headless frames
  outrun. Same for the render tools (`hud_shot`, `shot_runner`, `scar_shot`,
  `species_shot`) — they need a real renderer.
- **Red `ERROR:` lines during M1 tests 2, 5, 7 and 8 are EXPECTED.** Those tests
  deliberately provoke the error paths. Only lines beginning `FAIL:` are
  failures.

Then open it and click something:

```bash
"$GODOT" --path . --editor
```

The click-to-chop input layer is not headless-verifiable and never has been — it
is eyeball-tested by pressing F5 and swinging at a log.

---

## 5. Traps that bite on a new machine specifically

**Run every `godot --path .` from `the-axeman\`, not from the repo root.** The
repo root has no `project.godot`, so the engine quietly falls back to the
project manager: it prints its banner, runs NOTHING, and exits 0 (or segfaults
under `--headless`). A whole suite "passing silently" or "crashing" is almost
always this. `--verbose` gives it away — you will see it load editor settings
and never load a project.

**Your save does not travel.** The game writes to
`user://the_axeman_save.cfg`, which on Windows resolves to
`%APPDATA%\Godot\app_userdata\the-axeman\the_axeman_save.cfg`. It is outside the
repository on purpose — it is your progress, not the project's. A fresh machine
therefore starts at zero cash with an empty yard. If you want your desktop
progress on the laptop, copy that one file across by hand. A save from a *newer*
build is refused and moved aside to a `.bak` rather than loaded, so a
version-mismatched copy will not corrupt anything.

**Line endings are pinned, so don't fight them.** `.gitattributes` at the repo
root and inside `the-axeman/` both force LF in the index and in the working
tree, on every machine, whatever that machine's `core.autocrlf` happens to be.
This is what stops a laptop checkout from showing every `.gd` and `.tscn` file
as wholly modified. Do not set `core.autocrlf` per-machine to "fix" a diff — if
you see a whole-file diff, the attributes are being bypassed, and that is the
bug.

**The editor clobbers hand-edited `project.godot`.** If the Godot editor is open
when `project.godot` is edited by hand (or updated by a `git pull`), the editor
overwrites it on its next save. Close the editor before pulling, and reopen it
after. Re-run `m2_acceptance` if you suspect it happened — it asserts the base
canvas and `Action_Viewport.size` are equal, which is exactly the setting a
clobber reverts.

---

## 6. Working across two machines

There is one repo and no build server, so the discipline is just the ordinary
one:

- **Commit and push before you leave a machine.** The project has been under git
  only since 2026-08-01 and the habit is still new.
- **Pull before you start**, with the Godot editor closed.
- `.godot/` is not shared, so each machine builds its own import cache once and
  then never thinks about it again.
- `.claude/settings.local.json` is per-machine and gitignored. Permissions meant
  to apply everywhere go in `.claude/settings.json`, which is committed.
- The stale root-level `core/` and `data/` folders are **not** the live code —
  the canonical copies are inside `the-axeman/`. They are kept because
  `handoff/00_OVERVIEW.md` says not to delete them, and they are a standing
  invitation to edit the wrong file. Check your path before you edit.

---

## 7. Where the documentation lives

| File | What |
|---|---|
| `CLAUDE.md` / `AGENTS.md` | The operative source of truth: current status, frozen contracts, amendment log, every bug this project has paid for. Read first. |
| `handoff/00_OVERVIEW.md` | The handoff pack's index. |
| `handoff/02_M4_CHOPPING_BLOCK.md` | The live chopping implementation. |
| `handoff/07_M4_SLICING_POC.md` | Render and debug traps for the slicer. |
| `handoff/08_COZY_LUMBERYARD_ROADMAP.md` | The binding post-pivot roadmap. |
| `handoff/10_EARTH_TO_ALIEN_TIMBER_ROADMAP.md` | The long-horizon module sequence. |
| `INSTALL_M1.md` | The original M1 drop instructions — historical. |
