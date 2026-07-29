# High ROI iOS Code Sweep - 2026-07-18

Read-only sweep of the Meshtastic iOS app for small or medium fixes with high field usability impact. This report is grounded in local source inspection and the local beads tracker in `Meshtastic-Apple`.

## Context

- Primary epic: `meshtastic-apple-1ei` - Burning Man field usability improvements for Meshtastic iOS.
- New beads captured during this sweep: `meshtastic-apple-1ei.16` through `meshtastic-apple-1ei.21`.
- Existing beads already cover stale PKI diagnostics, relative dates, map location recency, Nodes redesign, and delivery diagnostics.
- No source changes were made as part of this sweep.

## Highest ROI

### `meshtastic-apple-1ei.16` - Await radio send before reporting message send success

`Meshtastic/Accessory/Accessory Manager/AccessoryManager+ToRadio.swift:373` starts the actual `send(toRadio)` work inside an unawaited `Task`, then saves the local message and lets `sendMessage` return. UI callers can therefore believe the send completed before the BLE/radio write path has completed.

Why it matters: drafts can clear and local messages can appear accepted even if the radio write fails.

Likely fix size: small to medium. Await `send(toRadio)` inline, propagate errors, and only clear UI after the write path has actually completed.

### `meshtastic-apple-1ei.17` - Retry should preserve failed message until resend is accepted

`Meshtastic/Views/Messages/RetryButton.swift:57` deletes the failed `MessageEntity` before attempting resend at line 65.

Why it matters: under bad RF/BLE conditions, retry can remove the only visible failed message and payload.

Likely fix size: small. Keep the old row until resend is accepted, or mark it retrying and restore it on failure.

### Existing `meshtastic-apple-1ei.5` - Auto-detect and repair stale PKI contact metadata

`Meshtastic/Accessory/Accessory Manager/AccessoryManager.swift:675` dispatches only `.decoded` packets. Undecoded encrypted packets still flow through generic metadata update, but there is no diagnostic branch for encrypted packets addressed to the connected node.

Why it matters: this matches the observed stale-PKI failure mode where the radio sees a direct packet but the app does not surface a useful message or repair hint.

Likely fix size: small to medium. Add an encrypted/undecoded branch that logs a diagnostic event and, when `packet.to == activeDeviceNum`, surfaces possible PKI/channel repair.

### `meshtastic-apple-1ei.18` - Map node pins should refresh liveness as last-heard ages

`Meshtastic/Views/Nodes/MeshMapMK.swift:250` hashes visible position identity, lat/lon, and precision, but not `lastHeard` or an online/offline bucket. Pins render from `snapshot.isOnline` at `MeshMapMK.swift:314`, and that snapshot is built from `node.isOnline` at `MeshMapMK.swift:1410`.

Why it matters: a stationary node can remain visually online after the 2-hour liveness threshold until another map/input change rebuilds the snapshot.

Likely fix size: small. Include `lastHeard` or a computed online bucket in the visible-position key, or force a light periodic liveness refresh.

## Small UX Fixes

### Existing `meshtastic-apple-1ei.3` / `.4` - Relative dates and location recency

Standard node rows still show absolute timestamps in `Meshtastic/Views/Nodes/Helpers/NodeListItem.swift:303`, while compact rows have an optional relative mode. The map popover displays position time at `Meshtastic/Views/Nodes/Helpers/Map/PositionPopover.swift:51`, but labels it as "Heard", which does not distinguish node heard time from location report time.

Why it matters: stale location and stale contactability are different failure modes. Field users need that distinction without opening multiple detail views.

Likely fix size: small. Default to relative time in primary rows, apply the policy consistently, and label map time as "Location reported ...".

### `meshtastic-apple-1ei.19` - Distance filter should make unknown-location behavior explicit

`Meshtastic/Views/Nodes/NodeList.swift:483` returns true for nodes with no known position when distance filtering is active.

Why it matters: a "nearby" or "within distance" view can still include nodes whose distance is unknown, burying useful positioned nodes.

Likely fix size: small. Exclude unknown-location nodes under distance filtering, or add an explicit "include unknown location" option.

### `meshtastic-apple-1ei.20` - Phone location sharing loop should survive one failed position send

`Meshtastic/Accessory/Accessory Manager/AccessoryManager+Position.swift:29` calls `sendPosition` inside a repeating task without catching per-iteration errors.

Why it matters: one transient GPS or send failure can stop future provided-location updates until reconnect/reinitialization.

Likely fix size: extra small to small. Catch and log per iteration, then continue.

## Worth Doing, Slightly Less Urgent

### `meshtastic-apple-1ei.21` - Device metadata updates should not orphan prior metadata rows

`Meshtastic/Helpers/MeshPackets.swift:395` always inserts a new `DeviceMetadataEntity` and assigns it to `node.metadata`. The relationship uses `.nullify` in `Meshtastic/Model/NodeInfoEntity.swift:69`, so older rows can become orphaned.

Why it matters: repeated reconnects or event sessions can grow stale metadata and make backups/restores noisier.

Likely fix size: small. Update existing metadata or delete the previous metadata row before replacement.

### Notification priority should be category-driven

`Meshtastic/Helpers/LocalNotificationManager.swift:58` sets default sound and line 59 sets `.timeSensitive` for all notifications created through this manager.

Why it matters: friend watch, georeminders, delivery diagnostics, and ambient BLE light alerts should not all have the same interruption behavior.

Likely fix size: small to medium. Add notification kind/priority and choose sound/interruption level per category.

## Follow-up Order

1. Fix send/retry trust first: `meshtastic-apple-1ei.16`, `.17`, and existing `.2`.
2. Fix stale inbound diagnostics: existing `meshtastic-apple-1ei.5`.
3. Fix map/list recency: existing `.3`, `.4`, plus `.18`.
4. Tighten location filtering and location-provider resilience: `.19`, `.20`.
5. Clean persistence/notification rough edges: `.21` and notification category work.
