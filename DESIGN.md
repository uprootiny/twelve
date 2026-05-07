# Design

## What twelve actually is

A *re-verification pane* for a workspace. The single page renders twelve
capacity cards — files, services, sample data, remote scripts — and on each
load asks the server to re-confirm presence from primary evidence: file
stat, AST parse, SSH probe. Cards turn red when reality disagrees with the
page text. Composition recipes underneath join 2–4 cards into a single
runnable thing.

## Why this shape

Sessions kept losing track of what was actually live versus aspirational.
A previous reflection literally named it: *"trail of /tmp/ artefacts, none
folded into repo."* The classic failure was a session naming the bug in
its dying breath, then losing the work. The repeated POSTMORTEM patterns
in solvulator (scattered codebases, port collisions, contract drift, the
12-agent pipeline parsed-but-unfueled because keys weren't in the env)
all share a shape: **claim drifted from reality, with no force pulling
them back into agreement**.

Twelve is the force. Every walkthrough re-verifies. Stale claims can't
hide.

## Two principles

### 1. Verified-present over aspirational

Cards count things confirmed by parse / file-stat / SSH probe — never
from memory or wishlist. Friction shows as friction. The pipeline runner
parses but the env file is missing? That's "warn / one fix away," not
"live." The remote drift detector exists in `/tmp/` on hub2 but only one
of five files survived? That's an honest "1 of 5," not a green
checkmark.

The cure for boosterism is not less generation — it's a re-verification
pass between generation and display.

### 2. Sheet-isomorphism

Every UI, every backend state shape, every "spec / reasoning / view" we
build for solvulator must map cleanly to a set of dynamic smart Google
Sheets. Rows = entities (cases, notices, capacities, agents). Columns =
fields (verified, parses, evidence, status). Views = saved filters /
pivot tables. Reasoning = formulas / cross-sheet references.
Compositions = named ranges or pivots.

Twelve's `/verify` endpoint already happens to be sheet-shaped: each
card is a row, each field is a column. The composition recipes are
named ranges that join cards. A future deployment could literally render
itself by reading a published sheet.

## What twelve isn't

- **Not a dashboard.** Dashboards aggregate metrics over time. Twelve is
  a *now* statement: what is here, what can be brought live this minute.
- **Not a CI status page.** It checks workspace files, not pipelines.
- **Not a service registry.** It's per-workspace — a different `TWELVE_ROOT`
  walks a different tree, with different cards making sense.
- **Not a CMS or wiki.** The text on the page is the static fallback;
  truth is in `/verify`. If you find yourself editing card prose to track
  reality, you're on the wrong tool — extend `verify()` instead.

## Extension model

Adding a card: write a check in `verify()` that returns `{label, evidence,
status}`, then add an `<article class="card">` in `verified-twelve.html`
with matching `.idx` text. The script at the page bottom binds them by
that index.

Adding a recipe: append to the `joins` section of the page. Recipes name
2–4 cards by id and give one shell snippet per recipe. The composition
chips on each card list which recipes that card participates in.

Adding a surface (separate small app at a new subdomain): see DEPLOY.md.
Each surface is a small repo of its own, with its own port and verify
shape, deployed via the family pattern.

## What changes if a check fails its premise

Twelve's verify checks should encode falsifiable claims. If a check goes
green but the underlying capacity doesn't actually work (e.g. card 01 was
hardcoded `"status": "ok"` regardless of file presence — this happened
and was fixed in commit 15b9a75), that's a verification *bug* and the
fix is to tighten the check. The cure for a false green is not a
disclaimer — it's a better predicate.
