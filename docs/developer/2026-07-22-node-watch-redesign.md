# Node Watch Redesign — 2026-07-22

Design notes for reworking `meshtastic-apple-1ei.10` (Node Watch) before continuing
implementation. Written mid-session so nothing is lost across a context compact.

## Where this came from

`.10` originally shipped (this session) as three new UI surfaces on top of an
already-existing-but-unreachable backend:

- Toolbar "eye" icon in `NodeList`'s bottom bar → opens a full-screen `NodeWatchList` sheet
  (add-by-ID field, "Watching" section, searchable "Known Nodes" picker).
- `WatchNodeButton` — a second per-node toggle, next to `NodeAlertsButton` (the bell), in both
  `NodeList`'s context menu and `NodeDetail`'s Actions section.
- Backend (pre-existing, from the prior session, previously unreachable): `UserDefaults.
  watchedNodeNums: Set<Int64>`, checked in two places in `UpdateSwiftData.swift` — new-node
  discovery, and an offline(>2h)→online transition on an existing node.
- This session added short-id (4-hex-char suffix) support: `UserDefaults.
  watchedNodeIdSuffixes: Set<String>`, `NodeWatchIdentifier.{parse,normalizedSuffix,
  hexIdMatches,isWatched,promoteSuffixMatch}` in `Meshtastic/Helpers/NodeWatchIdentifier.swift`.

User feedback on that shape: **too much new chrome** ("bloat"), and the concept should read as
**subscribing** to a node rather than a separate parallel feature. Agreed redesign (not yet
implemented):

1. **Fold into the existing bell** (`NodeAlertsButton`) instead of a second `WatchNodeButton`.
   The bell becomes a small menu with two independent toggles — "Messages" (today's mute/
   unmute) and "In range" (presence subscribe, today's Node Watch). One existing button, no
   new one.
2. **Blind short-id subscribe lives in the search bar's empty-results state** in `NodeList`
   (`FilteredNodeList`), instead of a dedicated add-by-ID screen: search for `9f79`, get zero
   matches, see "Notify me when '9F79' appears" inline.
3. **Review active subscriptions via the existing filter sheet** (`NodeListFilter` /
   `NodeFilterParameters`) as a new "Subscribed" toggle, instead of a dedicated list screen.
   `NodeFilterParameters.matchesPostPredicate` (defined in `NodeList.swift`, the post-`
   #Predicate` in-memory filter pass already used for search/online/role/etc.) is the right
   place — `NodeWatchIdentifier.isWatched(_:)` isn't `#Predicate`-expressible.
4. **Delete**: `NodeWatchList.swift`, the toolbar eye icon + `showingNodeWatch` state/sheet in
   `NodeList.swift`, `WatchNodeButton.swift` and its two call sites, and their pbxproj entries.
   Keep `NodeWatchIdentifier.swift` and both `UserDefaults` sets — still the matching engine.

**Status: approved, not yet implemented.** No code has been touched for this redesign yet this
session (still mid-exploration of `NodeFilterParameters`/`NodeListFilter`/`matchesPostPredicate`
when this doc was requested). The three-button version above is what's on disk right now.

## New questions raised (this message)

> think through the notification design and what happens when you click on notification. also
> how do we ensure it's not missed, and that the user sees it - most likely we'll need a
> dedicated piece of UI to clear the subscription in a way. but it should not be destructive -
> eg. these nodes should be added into a new list after we "unsubscribe" from them

### 1. Notification tap target

Already implemented and, I think, still correct: both trigger sites schedule a notification
with `path: "meshtastic:///nodes?nodenum=\(packet.from)"`, which `Router.route(url:)` resolves
to Node Detail for that node (documented in `docs/developer/deep-links.md`). Tapping takes you
straight to the person — map position, message button, etc. are all one screen away. No change
proposed here unless we want it to land on the map instead (see open question below).

### 2. Notification frequency (answered earlier, restated for the record)

- Fires once on first-ever discovery of a matching node.
- Fires again on **every** offline(>2h)→online transition, no cap, no cooldown, no dedup. A
  node that cycles in and out of range several times over a multi-day event produces several
  notifications, one per reappearance. This was flagged as intentional-but-worth-knowing, not
  yet changed.

### 3. "Not missed" — the real gap

A transient system notification is not enough for something this important (finding a specific
person at Burning Man). iOS Notification Center already retains delivered notifications until
the user clears them, which is *some* durability, but nothing in-app surfaces "you have N
subscription events you haven't looked at" if the user missed the banner and later clears
Notification Center or is in Do Not Disturb.

Proposed: a **persistent in-app subscription activity log**, independent of the ephemeral OS
notification — e.g. "Alice appeared at 3:42 PM", "Bob back in range at 5:10 PM" — plus a badge
(on the bell-menu affordance, or the Nodes tab) counting unread events since last viewed. This
is the natural answer to "how do we ensure the user sees it": don't rely solely on the OS
banner; keep our own record the user can check later on their own schedule.

### 4. Non-destructive unsubscribe

Current behavior (both the shipped `WatchNodeButton` and the planned bell-menu toggle): turning
a subscription off just removes the entry from `watchedNodeNums`/`watchedNodeIdSuffixes` — no
trace left. User wants this to be **non-destructive**: unsubscribing should move the entry to a
separate list (something like "previously watched" / history) rather than deleting it outright,
so:

- You can see who you used to watch.
- One-tap re-subscribe without re-typing an ID.
- An accidental toggle-off doesn't lose the fact you were tracking someone.

### Proposed data model change

Juggling two flat `UserDefaults` sets was fine for "on/off". It doesn't hold up once we need
timestamps (subscribed-at, last-notified-at, unsubscribed-at) and a non-destructive history
state. Recommend replacing `watchedNodeNums` + `watchedNodeIdSuffixes` with a single SwiftData
entity, e.g.:

```swift
@Model
final class NodeSubscriptionEntity {
    var nodeNum: Int64?      // set once resolved (exact watch, or a suffix watch that matched)
    var suffix: String?      // set for an unresolved short-id watch; cleared on promotion
    var subscribedAt: Date
    var lastNotifiedAt: Date?
    var unsubscribedAt: Date?  // nil = active; non-nil = history, not deleted
}
```

This subsumes `promoteSuffixMatch` (just set `nodeNum` and clear `suffix` on the same row
instead of moving between two sets), gives the activity log something to query
(`lastNotifiedAt`, or a separate lightweight event log keyed to this entity if we want more
than "most recent"), and gives the history list a natural query (`unsubscribedAt != nil`).
Matches this codebase's existing convention of SwiftData for anything with more shape than a
single flag (see `MeshtasticSchemaV1.models`) — `UserDefaults` was reasonable for a same-day
MVP, less so now that the feature has real state transitions.

This is a bigger change than anything shipped so far under `.10` and touches both
`UpdateSwiftData.swift` trigger sites and `NodeWatchIdentifier`. Flagging before doing it rather
than silently expanding scope further.

## Resolution (2026-07-22, later) — answers to the open questions above

Superseded by a synthesis of three parallel design passes (not-missed/activity UX, subscribe
lifecycle/unsubscribe UX, accessibility). All three independently converged on the same
principle already used elsewhere in this app: **extend `NodeInfoEntity` like `favorite` does,
don't build a parallel activity-log system.** No dedicated screen for any of this — bell menu,
search empty-state, and the filter sheet remain the only three surfaces, per the redesign above.

### Final data model

Replace the two flat `UserDefaults` sets and the previously-proposed standalone
`NodeSubscriptionEntity` with two smaller, more targeted additions:

```swift
enum WatchState: Int, Codable {
    case none
    case active   // notifying
    case history  // unsubscribed, non-destructively retained
}

// Added to NodeInfoEntity:
var watchState: WatchState = .none
var watchLastAppearedAt: Date?      // last time a watch notification fired for this node
var watchLastAcknowledgedAt: Date?  // last time the user opened this node's detail; nil/<
                                     // watchLastAppearedAt means "unseen"

// New minimal entity, only for ids with no NodeInfoEntity yet (unresolved short-id/full-id
// subscriptions):
@Model
final class PendingNodeWatch {
    var idFragment: String   // 4-hex suffix, or a full id not yet seen
    var subscribedAt: Date
    var watchState: WatchState  // .active or .history; .none doesn't get a row
}
```

`NodeWatchIdentifier.promoteSuffixMatch` becomes: on match, set the real node's `watchState`/
`watchLastAppearedAt` (carrying over `.history` if the pending watch was already unsubscribed)
and delete the `PendingNodeWatch` row. Same one-time promotion behavior as today, just moved
onto real model fields instead of two `Set`s.

### 1. Not missed

- Nodes-tab `.badge()` = count of **distinct** watched nodes with an unseen appearance
  (`watchState == .active && watchLastAppearedAt != nil && (watchLastAcknowledgedAt == nil ||
  watchLastAppearedAt! > watchLastAcknowledgedAt!)`) — mirrors `AppState.unreadDirectMessages`,
  Combine-synced to the app icon badge the same way. A node cycling in/out of range overnight
  still contributes exactly one badge unit; `watchLastAppearedAt` just keeps overwriting.
- In `NodeList.swift`, extend the existing favorite-partition sort: unseen-watch nodes sort to
  the very top (above favorites), with a bold row + inline "Appeared 3:42 PM" line under the
  name. Steady-state watched (no unseen event) gets no extra row treatment — the bell icon
  already communicates "I'm watching this"; only the *unseen* transition needs to be loud.
- Opening that node's detail screen (deep link tap or manual navigation) sets
  `watchLastAcknowledgedAt = .now`, clearing just that node's badge contribution — granular
  per-node, not a blanket "mark all read," because at a festival the user needs to find *that*
  specific person, not just learn something happened.
- **No dedicated activity-log screen.** Fully rejected in favor of the above — every reviewer
  independently reached this conclusion.

### 2. Notification frequency — must fix before choosing an escalation tier

The accessibility pass flagged a real sequencing problem: the current uncapped/no-cooldown
firing (every offline→online transition) has to be fixed *first*, because it determines which
notification interruption level is appropriate, not the other way around.

- Add a per-node cooldown at the two `UpdateSwiftData.swift` trigger sites (e.g. skip firing if
  `watchLastAppearedAt` was set within the last N minutes — 30–60 min is reasonable for a
  presence signal, open to tuning). `watchLastAppearedAt` still updates every transition either
  way (for the row timestamp); only the *notification* is throttled.
- Default interruption level: `.timeSensitive` (iOS 15+, breaks through Focus/DND, **no
  entitlement required**) — appropriate once cooldown ships. Do **not** request the Critical
  Alerts entitlement for this: Apple review resists "social presence" as critical, and an
  uncapped stream would make it worse, not better. Leave Critical Alerts for a distinct,
  explicitly opted-in future "safety contact" tier if ever needed — separate from Node Watch.

### 3. Non-destructive unsubscribe & history

- Same bell-menu toggle, no confirmation dialog. "Non-destructive by default" *is* the safety
  net — toggling "Notify when online" off just sets `watchState = .history`; the same toggle
  flips it back on in one tap. Reserve confirmation for the one genuinely destructive action:
  swipe-to-delete on a `PendingNodeWatch` history row (permanently forgetting an unresolved
  short-id ghost — the only case where data actually disappears, since real nodes stay in the
  DB regardless of `watchState`).
- History for **real nodes**: no separate section needed — they're already rows in the main
  list; `watchState == .history` is just metadata, visible via the bell menu and a new
  "Previously watched" toggle in `NodeListFilter`/`NodeFilterParameters`.
- History for **pending (unresolved) watches**: rendered as synthetic rows (id fragment, muted
  styling, no signal/telemetry) only when "Previously watched" is toggled on — hidden by
  default so unresolved typos/abandoned suffixes don't clutter the primary list.
- Resubscribe reuses the same bell-menu control in both cases — no second code path.

### 4. Notification tap target

No change from current behavior — Node Detail via `meshtastic:///nodes?nodenum=`, per the
original analysis in this doc. None of the three reviews raised a reason to prefer the map, and
Node Detail is one tap from both the map and messaging.

### Renames (accessibility pass, cheap, do these while touching the bell menu)

- "In range" → **"Notify when online"** — the trigger is a mesh presence transition, not
  physical proximity; "in range" risks being read as "nearby right now," which matters at a
  safety-adjacent event.
- Align polarity with the existing "Messages" toggle so both toggles mean "I get notified" —
  avoids a mixed-polarity mis-tap risk (mute vs. subscribe) in a small one-handed/gloved menu
  target. Concrete labels: **"Message alerts"** / **"Presence alerts"** (or "Notify when
  online"), with an `accessibilityHint` on the presence toggle: "Sends a notification when this
  node reconnects to the mesh."

## Next steps

1. Implement the approved 4-point redesign (bell menu — with the renamed/polarity-aligned
   toggles above, search empty-state, filter toggle, deletion of `NodeWatchList.swift`/
   `WatchNodeButton.swift`/toolbar icon) — nothing done yet.
2. Add `watchState`/`watchLastAppearedAt`/`watchLastAcknowledgedAt` to `NodeInfoEntity` and the
   new `PendingNodeWatch` SwiftData entity (add to `MeshtasticSchemaV1.models`); migrate
   `NodeWatchIdentifier` and both `UpdateSwiftData.swift` trigger sites off the two
   `UserDefaults` sets.
3. Add the per-node notification cooldown at both trigger sites; switch scheduled notifications
   to `.timeSensitive` interruption level.
4. Add the Nodes-tab badge (`AppState`, Combine-synced, mirroring `unreadDirectMessages`) and
   the top-of-list unseen-watch sort/row treatment in `NodeList.swift`.
5. Add the "Previously watched" filter toggle, synthetic pending-watch rows, and swipe-to-delete
   for `PendingNodeWatch` history rows.
6. Re-verify: Catalyst Debug build, `plutil -lint`, `git diff --check`.
