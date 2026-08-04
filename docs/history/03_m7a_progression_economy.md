# M7A — progression, the buyer, the pile, and swing rolls

Full build history behind the current progression summary. See
[README.md](README.md) for how this folder is organized. Current species and
progression behavior is summarized in `docs/areas/progression.md`; the full
ladder narrative remains recoverable from git history before the 2026-08-05
lean-doc refactor.

## M7A — progression spine (STARTED 2026-08-01, no sign-off yet)

Built ahead of the orders/prices because none of it needed a tuning value or an
asset. Suite: `m7a_acceptance` 85/85 (at the time this slice landed).

- **Cash and lifetime wood chopped live in `GameState`.** Cash is an `int`,
  never a float. It leaves the purse ONLY through `try_spend_cash()`, which is
  atomic — a refused purchase changes nothing and emits nothing (Amendment 4's
  all-or-nothing rule, applied to money). `DEFAULT_CASH = 0` is a PLACEHOLDER.
- **`lifetime_wood_chopped` is fed by the existing A7 `resource_gathered`
  signal** — no contract change, no edit to the chopping game. It filters on
  `ItemCategory.RAW_WOOD` rather than a list of wood ids **on purpose**: that
  survives the still-open `*_log` vs `*_firewood` rename, and picks up a new
  species for free. Monotonic by construction — it never sees removals, so
  selling stock cannot un-chop wood.
- **Two LOCAL signals** on GameState — `cash_changed`, `lifetime_wood_chopped_
  changed` — following Amendment 2's precedent exactly: NOT on EventBus, A7
  untouched, they never cross the 2D/3D boundary, and they exist so the M7 UI
  can update without polling.
- **`res://core/save_system.gd` (`class_name SaveSystem`) is NOT an autoload.**
  It is stateless static methods, so it needs nothing an autoload provides, and
  a 5th autoload would have needed an amendment the way GameFeel did. Each
  system serialises ITSELF (`to_save_dict`/`apply_save_dict` on GameState and
  InventoryManager), so Directive 6 is never bypassed — SaveSystem only moves
  dictionaries to and from disk.
- Save file: `user://the_axeman_save.cfg` (ConfigFile — Variants survive
  natively, and it is readable when a save goes wrong). Written to a `.tmp`
  and renamed over the real file, so a crash mid-write cannot truncate a save.
  Versioned; a save from a NEWER build is refused and moved to a `.bak` rather
  than loaded or overwritten.
- **`main.gd` now loads at boot and saves on window close.** It sets
  `get_tree().auto_accept_quit = false` and saves in
  `NOTIFICATION_WM_CLOSE_REQUEST` — the only hook that still sees live state.
  Quitting is unconditional even if the save fails.
- **Autosave: on every persisted progression change.** This began as the Creative
  Director's 2026-08-01 call to save when inventory gains something, then widened
  on 2026-08-02 so cash, yard-pile state, XP, skills, species purchases and the
  selected wood cannot wait for another chop before they are safe. It is
  **coalesced**: a finished log touches inventory, XP, cash and pile state, but
  the deferred flush collapses the whole transaction to one write. Connections
  are made AFTER main's own load so restoration signals cannot immediately
  rewrite the file that was just read.
  The suite proves both sides: a batch writes nothing inside the transaction,
  and a woodshed purchase persists without waiting for another inventory move.
- `core/tools/save_probe.tscn` drives the save from outside the game (`dump` /
  `seed` / `quit` / `wipe`) — it predates the UI and is still the way to inspect
  a save from outside. Note it is a SCENE, not a `-s` script: a `-s` script
  replaces the main loop and the autoloads are never instantiated.

## M7A — the basic buyer, the yard HUD and the real entry flow (2026-08-01)

The second M7A slice, and again everything in it that needed a tuning value was
pushed into data instead of invented. **Still no sign-off (as of the slice
landing — see CLAUDE.md's status table for the current state).**

- **`res://data/price_table.gd` + `price_table.tres` (`class_name PriceTable`)**
  holds what the buyer pays per unit. **Creative Director call, 2026-08-01: pine
  2, oak 5, birch 10** — Sam chose the wide spread over a gentle one, so which
  wood you are cutting matters and unlocking a species is a real jump in income.
  `mahogany_firewood` sits at 25 as a PLACEHOLDER above birch; it has no art and
  Sam has not priced it. Nothing in code or in any test asserts a literal price
  (the checks assert price x count), so retuning is a one-line data edit.
  It is a SEPARATE resource and not a field on `ItemDef` because A8 is a frozen
  Part A contract (Directive 2), and because a price is a property of the market,
  not of the object — M7B's reputation and per-customer multipliers layer on top
  of these base values without touching the registry. **An id the table does not
  price is NOT sellable**; it must never fall through to a free sale.
- **`res://core/market.gd` (`class_name Market`) is NOT an autoload**, for the
  same reasons as SaveSystem: no state, and a 5th autoload would need an
  amendment. It is the always-available basic buyer (roadmap pillar 5) — buys any
  priced item, any quantity, any time, no contract to accept.
- **It writes NOTHING itself.** Stock leaves only through
  `InventoryManager.remove_items`, cash arrives only through `GameState.add_cash`,
  so Directive 6 holds: Market decides what a sale IS, the owners perform it.
- **A sale is atomic in both directions, and the ORDER IS LOAD-BEARING:** price
  the whole basket and refuse it entirely if any line is unpriced, then remove the
  stock in ONE aggregated `remove_items`, and only then pay. Paying first and
  failing to collect would mint money from nothing. Both halves are proven to fail
  without their fix (a mixed oak+stone basket part-sells without the per-line
  price check; swapping the order pays for a sale that never happened).
- **`res://scenes/2d_management/yard_hud.tscn/.gd`** is instanced under
  `Main/UI_Overlay` (A9 — gameplay UI never goes in UI_Canvas). Cash is the only
  permanent economy number; pile and lifetime totals remain saved background
  stats. The yard panel derives one next useful cash purchase from the live
  shop/woodshed catalogues, including a wood's level prerequisite, so it cannot
  drift from authored data. Chopping mode alone shows the haul progress bar.
- **THERE IS NO MANUAL SELLING** (Creative Director call, 2026-08-01 — see the
  auto-sell section below). The per-species sell rows and "Sell all" this HUD
  shipped with on the same day are GONE; `Market` is still the buyer, it is just
  called by the yard as each piece lands instead of by a button.
- **The shop is an empty room ON PURPOSE.** `assets/ui/coin.png` (Sam's art) is
  the shop's icon on the button and on its header; the panel itself says what
  will be sold there. Upgrades and new woods are blocked on Sam's numbers
  (Directive 3), so this is the door and the counter, with nothing on the shelves.
- **THE TEMP M KEY IS GONE.** "Go chopping" / "Back to the yard" emit the same A7
  `minigame_entered` / `minigame_exited` the key did, so `main.gd`'s A10 mode
  switch is unchanged and is now driven by the production path. The HUD switches
  its own view off the SIGNALS, not off the clicks.
- **`core/tools/hud_shot.tscn` renders the real main scene to PNGs** (yard,
  chopping, sold) — RUN NON-HEADLESS. Every numeric check here is green on a UI
  that is off-screen or covering the chopping block; this is `shot_runner` applied
  to the 2D side. It stashes the real save for the run.
- **SEEN IN THE SHOTS, Sam's call:** coming back from chopping leaves the last
  rendered 3D frame frozen behind the yard panel (A10 stops the viewport
  rendering, it does not clear it). It reads fine — the yard IS the chopping site
  — but if you want the yard to be its own view, that is a design decision, not a
  bug fix.

## M7A — the pile pays as it lands, and the load is hauled away (2026-08-01)

**Creative Director call, and it REPLACED the model shipped earlier the same day:**
*"I think we should have the pile of chopped wood still build up, but we shouldn't
be selling it manually — as soon as the pieces enter the pile, they should be
converted to their cash value. Once the pile hits 50 pieces, it can animate off
screen in a fun way, similarly to how it animates on to the pile after it is
chopped."*

- **A piece is bought the MOMENT IT LANDS.** `WoodPile.start_stacking` now takes an
  `on_piece_settled` callback and fires it as each piece comes to rest, so the cash
  ticks up in the same cascade the player is watching land, not in one lump before
  the wood has arrived. `chopping_minigame._on_piece_landed` is that callback: it
  adds the piece to the yard pile and sells it through `Market`, so the price table
  is still the one place a piece's worth is decided and Directive 6 still holds.
- **`auto_sell` (@export, default true) is OFF in `m4_acceptance`.** M4 tests the
  chopping game's YIELD contract — a finished piece deposits stock — and the
  economy would otherwise sell that stock out from under it. Two suites, two
  concerns; nothing about the deposit changed.
- **The pile is no longer a view of InventoryManager.** It could not be: the wood
  is paid for and gone by the time it is stacked. It is now a view of
  **`GameState`'s yard pile** (`add_to_yard_pile` / `clear_yard_pile` /
  `yard_pile_changed`, saved in `to_save_dict`) — a record of WORK DONE since the
  last load left, which is progression, which is why it lives there.
- **A LOADED SAVE lands after this scene is built** — a child's `_ready` runs
  before its parent's, so the pile builds empty and `main.gd` reads the save
  moments later. The `yard_pile_changed` connection is what makes a restored pile
  appear at all; the count check in `_on_yard_pile_changed` is what stops the
  pieces this scene adds one at a time from triggering a rebuild on top of the
  animation that is placing them.
- **Rebuilt, never patched.** `wood_pile.gd`'s arc packing is deterministic and
  has no way to pull one piece out of the middle of a stack, so a change rebuilds
  the whole pile instantly via `WoodPile.place_settled()` — which shares
  `_slot_layout`/`_sim_to_world` with the animated path, so a restored pile packs
  exactly like one the player watched being thrown together.
- **Stand-in pieces are made by SLICING that species' own log** — two centre cuts
  into a quarter column with jagged cut faces, which is what the first two clicks
  on it would produce. A box would have been cheaper and would have looked like a
  box next to the real pieces. Built lazily and cached per species, so a wood the
  player owns none of never loads its FBX. NOTE it calls `MeshUtils.jag_cut` with
  the SPECIMEN's material, not through `_jag_cut()`, which roughens only what
  matches the log currently on the block.
- **THE HAUL-AWAY at `max_pile_pieces` (50, Sam's number).** `WoodPile.start_hauling`
  lifts every piece, arcs it outward away from the stump and tumbles it off past
  the horizon in a staggered wave — the fly-in run backwards. It has its OWN
  animation list and its own `_haul_root` parent, deliberately independent of the
  stack coming in, so **the player can chop straight through a haul-away** instead
  of waiting for the yard to tidy itself. It pays nothing: the wood was bought as
  it landed.
- Verified by 15 checks in `m7a_acceptance`, including a full chop on the real
  scene (4 pieces, 5 cash each, hauled at the cap) and pile checks that count
  pieces AND look at where they are — distinct slots, stacked upward, more than one
  billet mesh — because a count-only check would pass on a build that dropped every
  piece inside the stump. Both halves are proven to fail without their fix
  (`auto_sell = false` kills the payout checks; disarming the threshold leaves the
  load sitting in the yard). RENDERED: `hud_shot` shoots the shop, a 40-piece pile
  and the haul CAUGHT MID-FLIGHT, which no counter could have told us.
- **The haul threshold is now discoverable without reviving a permanent pile
  counter.** Chopping mode shows a numberless "Next haul-away" progress bar. Its
  maximum and the production pile both inherit `GameState.YARD_PILE_CAPACITY`
  (Sam's 50), so the threshold still has one owner.

## M7A — a swing is a ROLL, and the shop sells the odds (2026-08-01)

**Creative Director call:** *"we should make sure the player doesn't split through
every time guaranteed, they should leave a scar on the log if they fail a hit. The
stat increase works towards easier spliting, higher tier logs have a harder % to
break through."* Sam then chose, from the options put to him: a roll with a PITY
BONUS; scars that WEAKEN the piece they are in; the protein bar as +5 points of
split chance; and a REAL swing cooldown for the coffee to cut into.

- **`_resolve_strike` owns the roll, NOT `_perform_split`.** That split is
  deliberate: `_perform_split` means "cut this piece" and is what
  `debug_slice_world` and the entire M4 suite drive, so M4 goes on testing geometry
  instead of luck. The new headless seam is `debug_swing_world`, with
  `debug_split_roll` forcing the outcome (-1 roll / 0 always fail / 1 always split).
- **`split_chance_for(piece)` is the whole sum in one place:** the wood's own
  `split_chance` (a field on `SpeciesDef` — **0.55 is Sam's: "roughly 45% to
  start" on the STARTING LOG**, so on 2026-08-02 it moved with that role from oak
  to Quaking Aspen; the other 24 are placeholders laid out down the Janka ladder,
  so the wood that pays most resists most), made easier as the piece gets
  smaller (`size_relief`), plus
  `scar_bonus` per scar already in it, plus `strength_step` per protein bar,
  clamped to `max_split_chance` (0.95) — a swing is NEVER a certainty, which is
  the thing Sam asked for by name. `m7a_acceptance` asserts the price/difficulty
  ordering against the species table, so a new wood cannot ship as both the most
  valuable and the easiest.
- **A SCAR IS DRAWN OUTWARD, NOT CARVED IN.** Geometry cannot subtract from a
  surface: the first implementation sank a V into the log and rendered completely
  invisible, because the bark in front of it drew over the top. The mark is laid
  just proud of the wood instead. (Godot's `Decal` node, the obvious tool, does
  not render under Compatibility.)
- **THE MARK GOES ON THE TOP FACE, ALONG THE CUT LINE** (Creative Director call:
  *"It would need to be on the top, the line in the direction the camera is facing
  from where the player clicked"*). The log stands on the block and the axe comes
  down on its top, so that is where the bite belongs — the first version put it on
  whichever SIDE the click ray entered through, which is where the ray hit but not
  where the axe went. The line runs along `UP x normal`; since `normal` is the
  camera's own right vector (see `_on_click`), that is the line the split would
  have opened, running away from the viewer.
- **It is ONE SOFT DARK LINE, shared by every wood, UNSHADED and translucent.** It
  went through two rejected versions: a prettier two-tone of each species' own
  inside grain (*"I am having a hard time seeing the scar, it can just be a dark
  color as well, so no need to have it match every log"*), then a solid near-black
  bar (*"the line is also way too dark, it should just be a soft-indicator of
  failure, a thin mark where an axe failed to punch through"*). Unshaded is the
  load-bearing part: a lit material dims into dark bark exactly where the mark
  matters most. Readable beats correct — a scar the player misses is a mechanic
  the player misses.
- Scars live as children of the piece, so they turn with it and die with it. A
  piece that finally splits takes its scars with it and the two halves start
  clean — correct, since the cleave went straight through the marks.
- **A failed swing shakes but does NOT stop time.** `GameFeel.register_impact`
  gained an optional `with_pause` argument (a public method, not an A7 signal, so
  no contract moved) and failures pass `false`. A11's hit-pause stays the
  punctuation of a real split, so the two outcomes feel different before the
  player has read a single number.
- **A failed swing now BOUNCES OFF THE LOG.** The split roll resolves on the
  `swing` animation's contact key; a success keeps Sam's authored follow-through,
  while a failure immediately branches to the editable `bounce` animation in
  `axe_swing_lib.tres`. Its first key is the exact contact pose, then it reverses
  the overhead approach, so the scar, thud, shake and recoil are one event. Run
  `core/tools/axe_shot.tscn -- --bounce` non-headless to render the failure beats.
- **The swing cooldown did not exist before this.** The game was gated only by one
  strike at a time plus the anticipation window, so there was nothing for "5%
  faster between swings" to shorten. `swing_cooldown` (0.3 s, PLACEHOLDER and the
  value most likely to want Sam's hand) is now a real gate, and coffee compounds
  5% off it per level.
- **`res://core/shop.gd` + `data/upgrade_def.gd` / `upgrade_table.tres`.** Shop is
  static and not an autoload, like Market and SaveSystem. **Levels are stored as
  BUILDING TIERS** through A7's existing `building_upgraded` — a shop upgrade is
  exactly what that frozen signal already describes, so nothing was added to the
  contract to sell a cup of coffee. NOTE `DEFAULT_BUILDING_TIER` is 1, so LEVEL =
  TIER - 1; every reader goes through `Shop.get_level()` so that lives in one
  place. A purchase is atomic and ordered: refuse if maxed, spend the cash, and
  only then raise the tier.
- Costs (25 / 40, growth 1.6-1.7, cap 10 levels) are PLACEHOLDERS. The two 5%
  effect steps are Sam's.
- Verified by 37 checks in `m7a_acceptance`, all forcing the roll so none of them
  depend on RNG, and proven to fail without their fix (make every swing split and
  9 go red; drop the strength term and the protein bar's check goes red).
  RENDERED: `core/tools/scar_shot.tscn` shoots a clean log, a scarred one and a
  split one for both a dark wood and a pale one — run it on any change to the mark.
- **`core/tools/split_odds.tscn` MEASURES THE FELT RATE, and it is not the
  authored one.** `split_chance` is the odds on the FIRST swing of a whole log;
  almost every swing after that lands on a smaller piece that `size_relief` has
  already made easier, and on wood the scars have already weakened. Sam reported
  *"I'm not really ever seeing the failures"* and the tool said why: at oak 0.7 /
  relief 0.5, only **19% of swings failed and 12 logs in 40 went down without a
  single failure**. At oak 0.55 / relief 0.2 it is **35% of swings, and 37 logs in
  40 show at least one failure**. Run it after touching any of those numbers —
  arguing about the authored value is arguing about the wrong number.

## M7A — introductory orders and the contract board (2026-08-03, tuning pending)

- **THREE AUTHORED PLACEHOLDER ORDERS ARE LIVE:** Campfire Warm-up (10 any, +5),
  Aspen Hearth Load (15 Aspen, +10) and Pine Campsite Load (20 Eastern White
  Pine, +30). These six values are isolated in `data/order_table.tres` and are
  explicitly awaiting Creative Director sign-off; no gameplay code asserts them.
- `core/orders.gd` is stateless like Market/Shop. It pays every landed piece
  through the unlimited Market first, then credits a matching active order, so
  unmatched work always auto-sells and a failed sale can never earn contract
  progress. One patient order may be active; completed orders are one-time.
- Active id/progress and completion history live in GameState, survive save/load,
  and emit local repaint/autosave signals without changing frozen A7.
- The yard has a data-driven Contract Board. Its brown panel is deliberately a
  native `StyleBoxFlat` placeholder; `hud_shot_2d_orders.png` proves all three
  choices and an active progress bar fit together at 1280×720.
- Verified by 21 added checks: `m7a_acceptance` reached **245/245** at the time
  (see CLAUDE.md's status table for the current count). M4 remained
  **55/55** and the slicer remained **34/34**.
- Still to do at the time this slice landed: the tangible cash-purchase
  catalogue. Its behaviours and tuning remain a Creative Director call. The
  unlockable-species requirement is complete through the level-gated,
  cash-purchased 25-wood ladder (see
  the current `docs/areas/progression.md` summary and pre-refactor git history).
