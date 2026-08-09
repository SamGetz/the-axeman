# Four-hour gameplay-loop audit

Last updated: 2026-08-09. Live code and acceptance tests outrank this summary.
All numeric tuning in resources remains explicitly provisional.

## Game identity

The Axeman is a finite tactile-progression comedy: the player learns a small,
physical chopping verb, turns it into a lumberyard, then scales that same ledger
to planetary and orbital absurdity. It is not an endless idle game and should
not ask the player to maintain a simulation after the joke has reached its best
ending. The intended first run is approximately 3h15, with slower novice runs
still reaching credits before four hours. Roughly half the session should remain
hands-on chopping, reading grain/scars and mastering new woods.

## Useful best-in-class patterns

| Reference | Pattern worth borrowing | Axeman application |
|---|---|---|
| *Universal Paperclips* | A mundane action escalates into a finite cosmic joke | The same wood ledger grows from one stump to exact Earth depletion and orbital production |
| *A Short Hike* | Compact completion, low friction, no padding after the emotional peak | Credits fire on the first complete orbital ledger; no mandatory postgame tail |
| *DREDGE* | Tactile trips alternate with short, purposeful upgrade decisions | Chopping remains the anchor; management appears in sparse phase-sized decisions |
| *Hardspace: Shipbreaker* | Material properties make repeated manual work readable and learnable | Five handling families change fresh bite, scar value and size relief across all 25 woods |
| *Cookie Clicker* | Automation creates legible order-of-magnitude escalation | Watched splitting grows into routes, planetary throughput and three absurd orbital lines |

The combination to protect is tactile competence plus spectacular scale. Pure
menu optimisation would erase the chopping identity; pure chopping would make
the 3.04-trillion premise feel decorative.

## Audit findings and corrections

| Problem found | Player-facing failure | Implemented correction |
|---|---|---|
| Several simultaneous objectives with weak hierarchy | The player can finish side systems before knowing the campaign goal | One persistent exact-progress objective across six derived phases |
| Repeatable commission board maintenance | Frequent menu returns interrupt the stump loop | Five campaign-timed choices total; one of three, one active, automatic progress and payout |
| Small commission premiums late in the campaign | Long work feels irrelevant beside project costs | Snapshotted reward anchors to the next species, launch project or alien production line |
| All terrestrial woods felt mechanically adjacent | The 25-species requirement risks becoming a checklist | Five handling families of five species, each with a different practical lesson |
| Mastery and XP could create a late wall | The player finishes a system long before or after its next gate | Short 5–7-log mastery targets, 155 required mastery logs and 159 projected no-bonus logs |
| Six small logistics purchases in sequence | Menu clicks outnumber meaningful operating decisions | Three bundled stages: Input Line, Routing Desk and Continuity Dispatch |
| Skill rewards could overrun or cap before their content | Hoarded points or post-Earth levels break Frontier pacing | Exactly 84 core points; three alien masteries grant exactly nine one-rank Frontier points |
| Four skill columns competed for attention | The tree becomes a spreadsheet and exposes future scope | One branch at a time, revealed by campaign phase |
| Automation arrived without a clear scale narrative | Growth feels like disconnected multipliers | Watched splitter → regional company → planetary machine → orbital company |
| Credits had no single authoritative gate | A subsystem could finish before the intended ending | Earth zero + three alien masteries + three lines + Frontier Master + first combined receipt |
| Numeric badges and stacked panels created UI pressure | The HUD asks for cleanup rather than play | Attention-only badges, compact standing chip and protected central stump |

## Intended first-run rhythm

These are validation bands, not final tuning values.

| Elapsed target | Dominant experience | Required hand-off |
|---:|---|---|
| 0–15 min | Learn contact, splitting, sale and first authored delivery | Player understands one log → reward → improvement |
| 15–40 min | New woods, short mastery arcs and first standing goal | Watched automation appears around 35 minutes |
| 40–75 min | Alternate chopping with three meaningful logistics/company choices | Regional company is operating around 70 minutes |
| 75–145 min | Master the wider catalogue while automation becomes visibly absurd | All terrestrial prerequisites complete without an XP/mastery wall |
| 145–165 min | Planetary machine consumes the exact remaining Earth total | Earth reaches exactly zero around 159 minutes |
| 165–200 min | Three short alien handling arcs, Frontier purchases and orbital lines | First combined receipt rolls credits around 3h20 |
| 200–240 min | Novice/error budget only | No mandatory grind should consume this reserve |

The deterministic grant-free report currently projects 159 terrestrial manual
logs, about 200 minutes including management/read time, and a 54.4% tactile
share. It is a consistency check, not a substitute for play.

## Experience rules going forward

- Do not add a mandatory currency, menu or progression track unless it replaces
  an existing decision of equal weight.
- A phase may introduce one primary question at a time; secondary systems should
  advance automatically or remain quiet.
- Every automation purchase must visibly change throughput, yard state or the
  scale of the next objective—not merely a percentage in a tooltip.
- Every required manual wood must teach or remix a handling lesson before it can
  count as mastery.
- Never generate another commission choice because the previous one completed;
  only a named campaign fact can open the next choice.
- Preserve at least 45% tactile time and the central stump sightline.
- Roll credits at the comic peak. Optional continuation may let the player look
  at the finished yard, but cannot be required for campaign closure.

## Remaining approval evidence

Run the two uninterrupted novice sessions in `docs/ALPHA_PLAYTEST.md`. Investigate
any run over four hours, any unexplained idle span over three minutes, any goal
ambiguity over 30 seconds, a sixth commission interaction, a core skill cap-out,
or a Frontier point with no matching purchase. Only that human evidence can turn
the labelled `.tres` pacing placeholders into approved values.

Benchmark references: [Universal Paperclips](https://www.decisionproblem.com/paperclips/),
[A Short Hike](https://ashorthike.com/), [DREDGE](https://www.dredge.game/), and
[Hardspace: Shipbreaker](https://store.steampowered.com/app/1161580/Hardspace_Shipbreaker/).
