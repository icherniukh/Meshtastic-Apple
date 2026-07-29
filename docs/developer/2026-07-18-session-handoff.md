# Session Handoff - 2026-07-18

This handoff records the current local state before clearing chat context.

## Repos And Tracker

- Workspace: `/Users/ivan/proj/meshtastic`.
- iOS app repo: `/Users/ivan/proj/meshtastic/Meshtastic-Apple`.
- Firmware repo: `/Users/ivan/proj/meshtastic/firmware`.
- iOS fork remote: `fork` -> `https://github.com/icherniukh/Meshtastic-Apple.git`.
- Upstream remote: `origin` -> `https://github.com/meshtastic/Meshtastic-Apple.git`.
- Local tracker: beads in `Meshtastic-Apple/.beads`, excluded from git.
- Main epic: `meshtastic-apple-1ei` - Burning Man field usability improvements for Meshtastic iOS.

## Current Dirty Worktree

Intentional local changes currently include:

- Earlier fixes:
  - `Meshtastic/Accessory/Transports/Bluetooth Low Energy/BLETransport.swift`
  - `Meshtastic/Export/WriteCsvFile.swift`
  - `Meshtastic/Views/Nodes/Helpers/Map/MapSettingsForm.swift`
  - `Meshtastic/Views/Settings/Logs/AppLogFilter.swift`
  - `Meshtastic/Views/Settings/UpdateIntervalPicker.swift`
  - `MeshtasticTests/WriteCsvFileTests.swift`
- High-ROI sweep report:
  - `docs/developer/2026-07-18-high-roi-ios-sweep.md`
- Signing/build prep:
  - `Meshtastic.xcodeproj/project.pbxproj`
  - `Meshtastic/Meshtastic.entitlements`
  - `Meshtastic/Meshtastic-Catalyst.entitlements`
  - `Meshtastic/Meshtastic-LocalDevelopment.entitlements`
- Diagnostic logging:
  - `Meshtastic/Accessory/Accessory Manager/AccessoryManager+ToRadio.swift`
  - `Meshtastic/Accessory/Accessory Manager/AccessoryManager.swift`
  - `Meshtastic/Accessory/Transports/Bluetooth Low Energy/BLEConnection.swift`
  - `Meshtastic/Accessory/Transports/Bluetooth Low Energy/BLETransport.swift`

Build scripts may refresh `Meshtastic/Resources/DeviceHardware.json`, `Meshtastic/Resources/images/image_manifest.json`, and download `Meshtastic/Resources/images/rak6421.svg`. Those generated changes were cleaned up during this session and should not be included unless intentionally refreshing hardware resources.

## Signing State

The project was changed away from upstream identifiers:

- Team set to `JY953A8ZBF`.
- App bundle IDs changed to `com.icherniukh.MeshtasticClient*`.
- Watch companion app bundle ID updated to `com.icherniukh.MeshtasticClient`.
- Full app/Catalyst entitlements now use `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)` for keychain access group.
- Debug iOS app build now uses `Meshtastic/Meshtastic-LocalDevelopment.entitlements`, a reduced entitlement set intended to avoid upstream-only account-gated capabilities during local development.
- Release still uses the full app entitlement file.

Current signing state:

- watchOS 26.5 was installed through Xcode because the primary scheme embeds a Watch app.
- The generic-iOS automatic-signing build produced the app, Watch, and Widgets artifacts for team `JY953A8ZBF`.
- `codesign --verify --deep --strict` accepts the generated iPhone app. Its embedded app identifier is `JY953A8ZBF.com.icherniukh.MeshtasticClient`; the Watch and Widgets artifacts use the matching fork identifiers and team.
- The signed fork app was installed and launched on the connected iPhone 17 Pro (`E96FFED7-B06B-5E81-9E7C-5612BC9CE5C6`).

## Diagnostic Logging State

Added logging-focused diagnostics:

- Outgoing radio send failures include message id, packet id, from/to, channel, `wantAck`, PKI, reply id, and the underlying error.
- Undecoded packets addressed to the active node log a compact warning with payload kind, packet id, from/to, active node, channel, `wantAck`, and PKI without dumping encrypted bytes.
- BLE write logs include serialized byte count and `withResponse` vs `withoutResponse`.
- Normal BLE central state transitions and successful disconnects are no longer logged at error level.

Related beads:

- `meshtastic-apple-1ei.2` - Message delivery diagnostics for field failures.
- `meshtastic-apple-1ei.5` - Auto-detect and repair stale PKI contact metadata.
- `meshtastic-apple-1ei.16` - Await radio send before reporting message send success.
- `meshtastic-apple-1ei.17` - Retry should preserve failed message until resend is accepted.
- `meshtastic-apple-1ei.22` - Prepare local fork build signing for Ivan dev account.

## Verification

Passing checks from this session:

```bash
xcodebuild -project Meshtastic.xcodeproj -scheme Meshtastic -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
plutil -lint Meshtastic/Meshtastic-LocalDevelopment.entitlements Meshtastic/Meshtastic.entitlements Meshtastic/Meshtastic-Catalyst.entitlements
git diff --check
```

Signed artifact validation completed after Xcode platform setup:

```bash
xcodebuild -project Meshtastic.xcodeproj -scheme Meshtastic -configuration Debug -destination generic/platform=iOS -allowProvisioningUpdates build
codesign --verify --deep --strict --verbose=2 <generated Meshtastic.app>
xcrun devicectl device install app --device E96FFED7-B06B-5E81-9E7C-5612BC9CE5C6 <generated Meshtastic.app>
xcrun devicectl device process launch --device E96FFED7-B06B-5E81-9E7C-5612BC9CE5C6 com.icherniukh.MeshtasticClient
```

Remaining field validation:

- Verify Bluetooth authorization and first radio connection on the installed fork app.

## Follow-Up Notes - 2026-07-18

### Corrected Signing State

- The prior `2PC3K63BBJ` team selection was incorrect. The app target's current Debug and Release settings use Ivan's updated team `JY953A8ZBF`; Watch and Widgets must use that same team.
- A sandboxed `security find-identity` probe reported zero identities, but Xcode successfully signed all generated targets. The app, Watch, and Widgets signatures use the `Apple Development: Ivan Cherniukh (2PC3K63BBJ)` certificate with `JY953A8ZBF` embedded team identifiers; the profile/team validation therefore succeeded.
- `xcodebuild -showsdks` reports the iOS 26.5 SDK. Refresh `xcrun devicectl list devices` before device install because an earlier CoreDeviceService startup failed before the watchOS platform download.
- The local Debug entitlement file still requests NFC, Siri, and communication-notification capabilities. Validate automatic provisioning per target and inspect the signed entitlements after the first successful device install. Release continues to select the full entitlement file and needs an explicit fork release policy if archives are required.

### Implementation Order And Gaps

1. Keep fork signing, diagnostics, CSV export, and the unrelated UI fixes in separate reviewable commits. Push explicitly to `fork`; `origin` is upstream.
2. Implement `meshtastic-apple-1ei.16` and `.17` as one local message-attempt state machine. Do not merely await the current send: a pre-save transport failure would otherwise leave no failed payload to retry. Distinguish radio-write acceptance from mesh ACK and retain the original failed row when retry is rejected.
3. Make `meshtastic-apple-1ei.5` a user-visible diagnostic and repair path, not only OS logging. App logs are exportable CSV, so explicitly decide whether public node identifiers are appropriate in exported field diagnostics.
4. For `meshtastic-apple-1ei.18`, include a derived online/offline result or an expiry-aware refresh tick in the map state. Hashing static `lastHeard` alone cannot trigger the two-hour status transition.
5. For `.20`, handle each provided-location send failure without terminating the repeating task. For `.21`, reconcile historical orphaned metadata rows as well as preventing new ones.
6. Add regression tests for send rejection, retry rejection, BLE write-without-response semantics, liveness expiry, metadata cleanup, and the out-of-range interval picker. Correct `docs/developer/testing.md`: it says there is no CLI test runner, but CI invokes `xcodebuild test`.

### Reliability Work In Progress

- `meshtastic-apple-1ei.16` and `.17` now persist an outgoing row before the radio write, await the write, and use a local retryable transport-failure state when the initial write rejects. The error is rethrown so the composer keeps its draft. Retry no longer deletes the failed row first; it changes that same row to a new packet id and pending state only after the replacement write succeeds.
- `meshtastic-apple-1ei.18` now includes each visible node's derived `isOnline` result in the map-state key. The existing two-second map refresh therefore rebuilds stationary pins when their two-hour liveness status changes, rather than rebuilding continuously.
- Both changes compile in the Catalyst Debug build with `CODE_SIGNING_ALLOWED=NO`. The focused XCTest target cannot currently start under Xcode 26 because `swift-snapshot-testing` 1.19.2 fails to compile (`UIImage` does not conform to `AttachableAsImage`); this is independent of these sources and leaves the new test coverage unexecuted.
- Catalyst builds regenerate `Meshtastic/Resources/DeviceHardware.json`, `Meshtastic/Resources/images/image_manifest.json`, and `Meshtastic/Resources/images/rak6421.svg`. They are currently dirty generated artifacts and should be reverted/removed before committing unless a resource refresh is intended.

### Direct Message Delivery Investigation

Tracker state:

- `meshtastic-apple-1ei.2` is `in_progress`. Its beads comments contain the field observations and capture limitations below.
- Do not close `.2`, `.5`, `.16`, `.17`, or `.18` from this evidence alone.

Validated field observations:

- The two affected nodes exchanged direct messages successfully on the prior day. The user reproduced the current asymmetry in the official app as well as the fork, so the fork's message UI and its local BLE-write changes are not the primary cause.
- One direct-message direction arrives at `Meshtastic_9f79`; the reverse direction remains `Waiting to acknowledge`. Earlier, the successful side was shown as `Delivered to mesh`.
- A traceroute between the same nodes returns no route. The iOS implementation sends traceroute as an unencrypted `tracerouteApp` packet with `wantAck`; it is not the PKI direct-message code path. It still requires a shared channel, so its failure alone does not rule out a PKI-contact asymmetry.
- The user had already checked the normal radio/channel configuration comparisons before this session. Do not repeat the generic region/preset/channel checklist without new evidence.

Raw radio capture:

- The locally visible radio advertises as `Meshtastic_9f79` and identifies itself as `!74dc9f79`. The Meshtastic CLI connected directly over BLE after its phone session was disconnected:

  ```bash
  meshtastic --ble D04895EA-BBCF-67AD-02AA-CD689719188A --listen --debug --timeout 180
  ```

- The radio receives live LoRa traffic while attached, so its receiver is not completely dead. Its local-stats telemetry snapshot at capture time reported `num_online_nodes: 2`, `num_total_nodes: 80`, `num_packets_rx: 7`, `num_packets_rx_bad: 2`, `noise_floor: -120`, and uptime `126` seconds. Treat this as one short post-boot snapshot, not a root-cause conclusion.
- A CLI NodeDB read returned 80 IDs but no decoded names/recency for the requested `show-fields`, so it did not identify the peer. No configuration was modified or reset.
- The attempted iPhone `idevicesyslog` capture must be ignored: the paired Mac-visible iPhone was running the fork bundle, while the user made the controlled send in the official app. The live relay also omitted the app's structured `Logger` records.
- Before the phone session was disconnected, direct CLI attachment failed because `Meshtastic_9f79` was no longer advertising. It connected normally after the user released it.

Next diagnostic action:

1. Obtain the other affected node's public node ID (`!xxxxxxxx`) from Node Detail; it is not secret.
2. With `Meshtastic_9f79` disconnected from its phone, issue one CLI-originated acknowledgement test from `!74dc9f79` to that peer while capturing output:

   ```bash
   meshtastic --ble D04895EA-BBCF-67AD-02AA-CD689719188A --dest !PEER_ID --sendtext CLI-REVERSE --ack --timeout 90 --debug
   ```

3. Interpret the raw result before changing any radio configuration: distinguish a local radio rejection, routing NAK/no-route/timeout, recipient receive without return ACK, and a PKI-specific failure. The CLI text command validates the route/ACK path; it is not by itself a replacement for the app's PKI direct-message construction.
