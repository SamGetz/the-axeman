# M3 — GameFeel (hit-pause · noise camera shake · register_impact)

Status at handoff: **designed, not built.** This doc is the design. Build it
as written unless Sam redirects.

## Scope fence

IN: a single GameFeel system providing (a) A11 hit-pause, (b) noise-driven
camera shake, (c) a public `register_impact()` API, (d) wiring to
`EventBus.action_hit_registered`, (e) loading `game_feel_config.tres`.
OUT: anything that swings an axe, spawns fragments, or plays sounds. M4 is
the first consumer; M3 ships with a test harness only.

## Binding contracts

- **A11 (verbatim):** `Engine.time_scale = 0.05`; restore via
  `get_tree().create_timer(duration, true, false, true)` (that 4th arg =
  ignore_time_scale). Guard overlapping pauses (counter/single owner) so
  time_scale never sticks low. All 2D production Timers set
  `ignore_time_scale = true` (Timer property, exists in 4.7).
- **A3:** the only size test anywhere is
  `piece.size_tier > GameFeelConfig.size_threshold` — M3 makes the config
  reachable; it does NOT add any other size predicate.
- Config schema is frozen (`data/game_feel_config.gd`, A8):
  `hit_pause_duration, camera_shake_amplitude, camera_shake_decay,
  log_hop_force, size_threshold` (+ `perfect_cut_throw_force`).
  M3 consumes the first three; the force values are M4's.
  Values in the `.tres` are placeholders — Sam tunes them live during M3/M4.

## ⚠ Gate zero: the autoload amendment

GameFeel wants to be an **autoload** (4th, after GameState): hit-pause is
global `Engine.time_scale` state needing exactly one owner (A11), and M4–M6
all consume it. But CLAUDE.md's A5 summary enumerates exactly three
autoloads, so adding one is a contract amendment. **Before writing code**,
propose to Sam:

> Amendment 5: add autoload `GameFeel` (`res://core/game_feel.gd`) as order
> 4, after GameState. Rationale: single owner for Engine.time_scale (A11
> guard), shared by M4–M6. EventBus/A7 untouched — `register_impact` is a
> method, not a signal.

On approval: log it in CLAUDE.md's amendment section, have Sam add the
autoload via the editor UI (Project Settings → Globals → Autoload — give
click-by-click steps; watch the project.godot clobber trap in
`00_OVERVIEW.md`). If Sam rejects the autoload, fallback design: a
`class_name GameFeel` node instanced inside each action scene + a static
singleton accessor — but propose the autoload first, it's the right shape.

## Design

### File: `res://core/game_feel.gd` — autoload "GameFeel"

```gdscript
extends Node
## FILE: res://core/game_feel.gd
## ATTACHES TO: nothing directly. Autoload "GameFeel" (order 4, after
## GameState — Amendment 5).

const _CONFIG_PATH := "res://data/game_feel_config.tres"
const _HIT_PAUSE_SCALE := 0.05   # A11 verbatim, not tunable

var config: GameFeelConfig      # read-only for everyone else

var _active_pauses := 0          # A11 overlap guard
var _trauma := 0.0               # 0..1
var _camera: Camera3D = null
var _noise := FastNoiseLite.new()
var _noise_t := 0.0
```

- `_ready()`: load config; `push_error` + fall back to `GameFeelConfig.new()`
  if missing/wrong class (never crash). Connect
  `EventBus.action_hit_registered → _on_action_hit_registered`, and
  `EventBus.minigame_exited → _on_minigame_exited`.
- `hit_pause(duration := -1.0) -> void`:
  ```
  if duration < 0.0: duration = config.hit_pause_duration
  Engine.time_scale = _HIT_PAUSE_SCALE
  _active_pauses += 1
  await get_tree().create_timer(duration, true, false, true).timeout
  _active_pauses -= 1
  if _active_pauses == 0: Engine.time_scale = 1.0
  ```
  Overlap semantics: any new pause re-pins 0.05; only the LAST expiry
  restores 1.0. Never restore while `_active_pauses > 0`.
- `register_impact(strength: float) -> void`: clamp strength to 0..1;
  `_trauma = clampf(_trauma + strength, 0.0, 1.0)`; call `hit_pause()`
  (fire-and-forget — it's async).
- `register_camera(cam: Camera3D) -> void` / `unregister_camera() -> void`:
  action scenes hand over their camera on enter, release on exit. Guard: if
  a different camera is already registered, `push_warning` and replace.
- `_process(delta)`: decay
  `_trauma = maxf(_trauma - config.camera_shake_decay * delta, 0.0)`.
  If camera valid and trauma > 0: shake via **`h_offset` / `v_offset`**
  (NOT position/rotation — never fight gameplay camera movement):
  ```
  var shake := _trauma * _trauma * config.camera_shake_amplitude
  _noise_t += delta * 60.0
  _camera.h_offset = _noise.get_noise_2d(_noise_t, 0.0) * shake
  _camera.v_offset = _noise.get_noise_2d(0.0, _noise_t) * shake
  ```
  When trauma hits 0 (or on unregister), zero both offsets exactly once.
- `_on_action_hit_registered(_pos: Vector3, _tier: int, _dir) -> void`:
  `register_impact(1.0)` — **the 1.0 is a placeholder**; ask Sam whether
  impact strength should scale with tool tier / piece size (likely an M4
  tuning conversation; note it in your delivery).
- `_on_minigame_exited()`: `_trauma = 0.0`, zero camera offsets,
  `unregister_camera()`. Do NOT force time_scale here — the counter owns it
  (a hit-pause in flight at exit still restores correctly via its timer,
  which ignores time_scale).

`_process` runs during hit-pause too (autoloads aren't paused) — that's
correct and desirable: shake decays in real time... **no**, `delta` IS
scaled by time_scale. Accept this: shake freezes during the 3-frame pause,
which reads as impact. Do not "fix" it with unscaled delta unless Sam asks.

### Camera wiring (touches M2 files — minimal)

`placeholder_action_scene.tscn` gets a tiny script on its root
(`res://scenes/3d_action/placeholder_action_scene.gd`, extends Node3D):
`_ready()` → `GameFeel.register_camera($Camera3D)`;
`_exit_tree()` → `GameFeel.unregister_camera()`.
Nothing else in M2 changes. (When it becomes processing-disabled in 2D mode
its _process stops but registration persists — harmless, trauma is zero.)

### Debug affordance (temporary, mirrors the M-key precedent)

In `main.gd`'s debug block: while in 3D mode, **H key** emits
`EventBus.action_hit_registered.emit(Vector3.ZERO, GameState.get_tool_tier(Enums.ToolType.AXE), Enums.ChopDirection.LEFT)`
so Sam can feel pause+shake before M4 exists. Mark it M3 TEMPORARY, remove
with the M-key block at M7. Tell Sam: run game → M → hammer H.

## Acceptance test — `res://core/tests/m3_acceptance.gd/.tscn`

Copy the M1/M2 `_check` pattern. This suite must `await`, so raise the
headless run to `--quit-after 120` or simply let checks await timers.

1. `GameFeel.config` is a `GameFeelConfig`, values match the `.tres`
   (spot-check `hit_pause_duration`).
2. `register_impact(0.5)` sets time_scale to 0.05 immediately.
3. After awaiting > hit_pause_duration real seconds
   (`create_timer(dur + 0.05, true, false, true)`), time_scale == 1.0.
4. **Overlap guard (the A11 killer test):** fire `hit_pause(0.05)` and
   `hit_pause(0.15)` 0.02s apart; at t≈0.08 (first expired, second not)
   time_scale is STILL 0.05; after both expire it's exactly 1.0. Fire 10
   overlapping pauses in a loop; end state 1.0.
5. Trauma: `register_impact(1.0)` then `register_impact(1.0)` → clamped
   (expose trauma via a `get_trauma()` getter for the test — fine to ship).
6. Camera: register a throwaway Camera3D, `register_impact(1.0)`, await one
   process frame → `h_offset != 0 or v_offset != 0`; then
   `EventBus.minigame_exited.emit()` → both offsets == 0, trauma == 0.
7. Strength clamp: `register_impact(50.0)` → trauma ≤ 1.0.
8. Re-run M1 + M2 suites afterward (M2 asserts main.tscn boots 2D — adding
   the root script to placeholder scene must not break it).

## Ask-Sam list for M3

- Amendment 5 approval (gate zero — before any code).
- Final tuning values for `hit_pause_duration`, `camera_shake_amplitude`,
  `camera_shake_decay` — offer to tune live: Sam runs game, M, H, you adjust
  the `.tres`, Sam re-runs (no code edits needed; that's the point).
- Whether impact strength varies by tool tier (can defer to M4).
