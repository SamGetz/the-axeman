# Private alpha tester instructions

These instructions apply after the blockers in `ALPHA_HANDOFF.md` are cleared.

## Install and launch

- Extract the ZIP to a normal writable folder. Do not run from inside the ZIP.
- macOS: open `the-axeman.app`. The build is unsigned and not notarized, so
  Gatekeeper may require an explicit **Open** confirmation from Finder.
- Windows: keep the `.exe` and `.pck` together, then run the `.exe`. The private
  build is unsigned and Windows may show a reputation warning.
- Use mouse and keyboard in the authored 1280×720 windowed layout.

## First-session check

1. Confirm the startup screen shows **New Game** and does not enter the yard by
   itself.
2. Start New Game and chop normally. Confirm cash, XP and the Earth counter move.
3. Follow the delayed tutorial. Jobs, Shop, Skills, Catalogue and Atlas should
   appear only when their named progression gate is earned.
4. Save by quitting, relaunch, choose **Load Game**, and confirm the same yard,
   cash, XP, purchases and active objective return.
5. Continue normally. Do not use test scenes, debug grants or save editing.

## Four-hour fresh-save timing pass

Run this with two players who have not seen the progression map. Start a timer
when **New Game** is pressed and play through credits without debug grants.
Record the first timestamp for: standing commission choice, watched Mechanical
Splitter, regional company, all 25 Earth woods mastered, Earth at zero, first
alien mastery, three orbital lines and credits.

Also record:

- every moment the next required action is unclear for more than 30 seconds;
- any mandatory wait longer than three minutes with no useful chopping or
  management choice;
- whether more than five standing commission choices appear, or whether a
  completed commission immediately opens another chooser;
- whether core skills cap before Earth is ready, or Frontier lacks exactly one
  purchasable rank per alien-earned point;
- total manual logs, final playtime, and whether chopping felt like roughly half
  of the session.

Target evidence is a median near 3h15 and a slow run below four hours. These are
review gates, not permission to relabel the `.tres` tuning placeholders as final.

## Report a blocker

Include platform/OS, build `0.15.0-alpha.1`, the last action taken, visible
objective, cash/level, and a screenshot. Treat these as blockers: an unreachable
required button, clipped requirement, missing objective, progression softlock,
parser/missing-resource message, renderer failure, or a save that cannot reload.

Placeholder geometry, generated candidate art, current UI skin and silence are
expected for this mechanics-focused alpha unless they hide a mechanic. Final
art/audio, controller support, installers, signing/notarization, settings and
post-M14 procedural content are out of scope.
