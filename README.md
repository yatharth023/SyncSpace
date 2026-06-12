# SyncSpace

> **Your Focus Session. Synchronized Everywhere.**
>
> A premium Apple-ecosystem focus companion that pairs a macOS productivity hub
> with an iPhone remote dashboard — entirely peer-to-peer, no internet required.

[![Platforms](https://img.shields.io/badge/Platforms-macOS%2026%20%7C%20iOS%2026-blue)](#)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](#)
[![UI](https://img.shields.io/badge/UI-SwiftUI-purple)](#)
[![Architecture](https://img.shields.io/badge/Architecture-MVVM-green)](#)

---

## Table of contents

1. [Product overview](#product-overview)
2. [Architecture diagram](#architecture-diagram)
3. [Technology stack](#technology-stack)
4. [Features](#features)
5. [Project structure](#project-structure)
6. [Installation](#installation)
7. [Running the macOS app](#running-the-macos-app)
8. [Running the iOS app](#running-the-ios-app)
9. [Multipeer Connectivity setup](#multipeer-connectivity-setup)
10. [SwiftData usage](#swiftdata-usage)
11. [Synchronization flow](#synchronization-flow)
12. [Data models](#data-models)
13. [UI design philosophy](#ui-design-philosophy)
14. [Accessibility](#accessibility)
15. [Offline functionality](#offline-functionality)
16. [Performance considerations](#performance-considerations)
17. [Networking design](#networking-design)
18. [Audio engine](#audio-engine)
19. [Haptic system](#haptic-system)
20. [Theme system](#theme-system)
21. [Page header system](#page-header-system)
22. [Demo walkthrough](#demo-walkthrough)
23. [Recent hardening pass](#recent-hardening-pass)
24. [Known challenges](#known-challenges)
25. [Roadmap](#roadmap)
23. [Future enhancements](#future-enhancements)
24. [Resume highlights](#resume-highlights)
25. [Interview talking points](#interview-talking-points)
26. [Developer notes](#developer-notes)
27. [Contributing](#contributing)
28. [License](#license)

---

## Product overview

SyncSpace is a focus-session ecosystem made of two native Apple apps that
co-operate over local Wi-Fi:

- **SyncSpace Hub** — a macOS productivity dashboard. Acts as the *host* device:
  the source of truth for timers, audio, tasks, and analytics.
- **SyncSpace Remote** — an iOS companion. Acts as a *remote*: glanceable
  dashboard, live mixer, haptic notifier, and second-screen visualisation that
  sits beside your monitor.

Both apps target macOS 26 / iOS 26 (current SDK), are written in 100% SwiftUI,
and share a single multi-platform Xcode target. They use Apple's
`MultipeerConnectivity` framework to discover, pair, and sync without any
server, cloud, or internet connection.

### Why it exists

Focus apps usually live on one device. SyncSpace recognises that a phone is
often **the** distraction sitting on your desk — so it turns the phone into a
*calm second screen* that visualises your session, broadcasts haptic cues at
key transitions, and gives you tactile remote control of the mix and timer
without breaking concentration on the Mac.

---

## Architecture diagram

```
                ┌──────────────────────────────────────────────────────┐
                │                   SyncSpace Hub (Mac)                │
                │                       — Host —                       │
                │                                                      │
                │ ┌─────────────┐ ┌─────────────┐ ┌────────────────┐   │
                │ │ Focus Timer │ │ Audio Engine│ │ Task & Session │   │
                │ │  (Authority)│ │  AVAudioE.  │ │   SwiftData    │   │
                │ └─────┬───────┘ └─────┬───────┘ └───────┬────────┘   │
                │       │               │                 │            │
                │       └────────┬──────┴─────────────────┘            │
                │                ▼                                     │
                │        ┌───────────────┐                             │
                │        │   AppModel    │ ← @Observable, MainActor    │
                │        │  Coordinator  │                             │
                │        └───────┬───────┘                             │
                │                ▼                                     │
                │        ┌───────────────┐                             │
                │        │  PeerManager  │ MultipeerConnectivity (TLS) │
                │        └───────┬───────┘                             │
                └────────────────┼─────────────────────────────────────┘
                                 │
              encrypted P2P over Wi-Fi / P2P Wi-Fi / Bluetooth
                                 │
                ┌────────────────┼─────────────────────────────────────┐
                │                ▼                                     │
                │        ┌───────────────┐                             │
                │        │  PeerManager  │                             │
                │        └───────┬───────┘                             │
                │                ▼                                     │
                │        ┌───────────────┐                             │
                │        │   AppModel    │ ← Mirrors host state        │
                │        └───────┬───────┘                             │
                │                ▼                                     │
                │ ┌──────────────┴───────────────────────────────────┐ │
                │ │  Dashboard │ Remote Mixer │ Tasks │ Haptics      │ │
                │ │   (orb)    │  (sliders)   │ (sync)│ (CoreHaptics)│ │
                │ └──────────────────────────────────────────────────┘ │
                │                                                      │
                │              SyncSpace Remote (iPhone)               │
                │                       — Remote —                     │
                └──────────────────────────────────────────────────────┘
```

The Mac is **always** authoritative. The iPhone only sends commands and
visualises state it receives.

---

## Technology stack

| Concern        | Choice                                                                     |
|----------------|----------------------------------------------------------------------------|
| Language       | Swift 5.9+ with strict concurrency (MainActor default isolation)           |
| UI             | SwiftUI (NavigationSplitView on Mac, TabView on iPhone)                    |
| State          | `@Observable` from the Observation framework                               |
| Persistence    | SwiftData (`TaskRecord`, `SessionRecord`)                                  |
| Networking     | MultipeerConnectivity (Bonjour `_syncspace._tcp` / `_udp`, encrypted)      |
| Audio          | AVAudioEngine + procedural DSP per ambient track                           |
| Haptics        | CoreHaptics on iOS, NSHapticFeedbackManager fallback on macOS              |
| Animation      | Spring/smooth animations, `matchedGeometryEffect`, symbol effects, content transitions |
| Charts         | Swift Charts (`BarMark`, `SectorMark`)                                     |
| Concurrency    | async/await + structured Tasks                                             |

The project is a **single multi-platform target** with `#if os(macOS)` and
`#if os(iOS)` guards. There is no UIKit or AppKit view code; only SwiftUI.

---

## Features

### macOS — SyncSpace Hub

- **Focus Session** with circular ring timer, breathing glow, and ambient
  background. Presets: 25-min Focus, 50-min Deep Work, 15-min Sprint, Custom.
- **Audio Mixer** with 5 procedurally-generated channels (Rain, White Noise,
  Cafe, Forest, LoFi). Custom vertical faders with live level meters.
- **Task Management** powered by SwiftData. Inline composer, completion
  toggle, double-click-to-rename, swipe-to-delete, filter chips.
- **Analytics** with Swift Charts: daily/weekly/monthly focus time, session
  mix donut, completion rate, streak tracking, recent sessions list.
- **Settings** for appearance, audio engine toggle, custom durations, history
  reset, connection diagnostics. Theme switching (System / Light / Dark) is
  reactive end-to-end — see [Theme system](#theme-system).
- **Sidebar Navigation** with animated `matchedGeometryEffect` selection.
- **Centered page-title capsule** (`PageHeaderCapsule`) shared across every
  destination — see [Page header system](#page-header-system).
- Global keyboard shortcuts (⌘P start/pause, ⌘R reset, ⌘. skip).

### iOS — SyncSpace Remote

- **Dashboard** with a pulsing focus orb that reacts to progress, audio
  energy, and breathing pulse.
- **Live Remote Controls** for start, pause, reset, skip. Each tap fires a
  custom haptic pattern.
- **Remote Mixer** with continuous sliders that send unreliable MC messages
  so the Mac's engine tracks gestures in real time (~50ms latency).
- **Tasks** with optimistic UI updates — toggling on iPhone immediately
  updates the Mac.
- **Custom CoreHaptics Patterns** for session start, pause, resume, and a
  distinctive double-bloom completion alert.
- **Auto-pairing** — once the Hub is advertising, the Remote silently invites
  it on launch.
- **Polished task entry** — `@FocusState` driven composer with
  `.scrollDismissesKeyboard(.interactively)`, tap-outside dismissal, and a
  keyboard-toolbar Done button so the keyboard never traps the user (matches
  Reminders / Notes / Mail).

---

## Project structure

```
SyncSpace/
├── SyncSpace.xcodeproj/                      # Single multi-platform target
└── SyncSpace/
    ├── SyncSpaceApp.swift                    # @main, model container, root
    ├── Info.plist                            # Bonjour service registration
    │
    ├── Shared/                               # Platform-agnostic code
    │   ├── Models/
    │   │   ├── SessionType.swift             # Built-in presets + custom
    │   │   ├── TimerState.swift              # Wire-serializable timer snapshot
    │   │   ├── AudioTrack.swift              # Track catalogue + tinting
    │   │   ├── AudioMixState.swift           # Per-channel + master volumes
    │   │   ├── TaskItem.swift                # Codable struct + @Model record
    │   │   ├── SessionRecord.swift           # SwiftData history entity
    │   │   ├── ConnectionStatus.swift        # High-level peering states
    │   │   └── SyncMessage.swift             # Discriminated union, commands
    │   │
    │   ├── Networking/
    │   │   └── PeerManager.swift             # MC wrapper, advertise/browse
    │   │
    │   ├── Services/
    │   │   ├── AudioEngineService.swift      # AVAudioEngine + DSP synths
    │   │   └── HapticManager.swift           # CoreHaptics patterns
    │   │
    │   ├── State/
    │   │   └── AppModel.swift                # Top-level @Observable coordinator
    │   │
    │   ├── Components/                       # Reusable SwiftUI views
    │   │   ├── BreathingBackground.swift
    │   │   ├── CircularTimerView.swift
    │   │   ├── ConnectionBadge.swift
    │   │   ├── LevelMeter.swift
    │   │   ├── PageHeaderCapsule.swift       # Centered page-title pill
    │   │   └── PulsingOrb.swift
    │   │
    │   └── Utilities/
    │       ├── DesignSystem.swift            # Spacing / radius / motion tokens
    │       ├── Theme.swift                   # Brand palette + gradients
    │       ├── ThemePreference.swift         # AppearanceMode + ThemeBridge
    │       ├── TimeFormatter.swift
    │       └── ViewModifiers.swift           # GlassCardStyle, ScreenHeader, InfoChip
    │
    ├── macOS/
    │   └── Views/
    │       ├── MacRootView.swift             # NavigationSplitView shell
    │       ├── MacSidebar.swift
    │       ├── FocusSessionScreen.swift
    │       ├── TasksScreen.swift
    │       ├── AudioMixerScreen.swift
    │       ├── AnalyticsScreen.swift
    │       └── SettingsScreen.swift
    │
    ├── iOS/
    │   └── Views/
    │       ├── iOSRootView.swift             # TabView shell
    │       ├── DashboardScreen.swift
    │       ├── RemoteMixerScreen.swift
    │       ├── RemoteTasksScreen.swift
    │       └── iOSSettingsScreen.swift
    │
    └── Assets.xcassets/
```

---

## Installation

### Prerequisites

- macOS 26 Sequoia or later (matches the deployment target)
- Xcode 26+ with the macOS 26 / iOS 26 SDKs
- An Apple Developer account (for code signing if you want to deploy to a
  physical iPhone)

### Get the code

```bash
git clone <repo-url> SyncSpace
cd SyncSpace
open SyncSpace.xcodeproj
```

### First build

The project is a single multi-platform target — no Swift package manager
dependencies, no CocoaPods. Just press **⌘B**.

---

## Running the macOS app

1. Select the **My Mac (Designed for Mac)** destination or any Mac in Xcode.
2. Press **⌘R**.
3. The macOS app launches into the **Focus Session** screen.
4. The window automatically begins advertising itself over Multipeer.

You can begin a focus session, mix ambient audio, and manage tasks without any
phone connected. Standalone mode works fully.

### Recommended demo flow

1. Open SyncSpace on the Mac.
2. Tap a session preset (e.g. 25-min Focus).
3. Open the **Audio Mixer** tab, drag the *LoFi* and *Rain* faders up — you
   should hear blended ambient audio immediately.
4. Add a few tasks under the **Tasks** tab.
5. Launch the iPhone app (next section) and watch everything sync instantly.

---

## Running the iOS app

1. Plug in an iPhone or boot the iOS Simulator.
2. Select the **SyncSpace** scheme with an iPhone destination in Xcode.
3. Press **⌘R**.
4. The app launches into the **Dashboard** tab and starts browsing for a
   nearby SyncSpace Hub.
5. When the host is found, the badge in the top-left turns green and the
   dashboard begins receiving live state.

> **Note on local network permission:**
> On first launch, iOS will prompt for local network access. Tap *Allow*.
> The prompt text is configured in `Info.plist`
> (`NSLocalNetworkUsageDescription`).

---

## Multipeer Connectivity setup

`MultipeerConnectivity` requires:

1. A Bonjour service registration in **Info.plist**:

    ```xml
    <key>NSBonjourServices</key>
    <array>
        <string>_syncspace._tcp</string>
        <string>_syncspace._udp</string>
    </array>
    ```

2. A local-network usage description (configured in build settings):

    ```
    INFOPLIST_KEY_NSLocalNetworkUsageDescription = "SyncSpace needs local network access to discover and sync with your Mac."
    ```

3. The same `serviceType` string on both ends. SyncSpace uses `"syncspace"`,
   defined as a static constant in `PeerManager`.

### Roles

- **Host (Mac)** — runs `MCNearbyServiceAdvertiser`. Auto-accepts any invite.
- **Remote (iPhone)** — runs `MCNearbyServiceBrowser`. Auto-invites the first
  host it sees so users never need to tap a "pair" button.

Both ends use `MCEncryptionPreference.none`. SyncSpace ships **no sensitive
payloads** — only timer state, audio mix, task snapshots, and remote commands
travel over the wire. `.optional` and `.required` both require both ends to
negotiate a session key; on freshly paired devices that negotiation stalls
intermittently and produced the "stuck on Connecting…" failure mode that the
project hit during testing. `.none` removes the failure mode while staying
appropriate for a local-network productivity app.

### Peer de-duplication

`MCNearbyServiceBrowser` publishes the same physical device under separate
`MCPeerID` instances when it sees it across more than one transport
(Wi-Fi + AWDL/Bluetooth). Identity-based de-duplication therefore misses
the duplicates and the same Mac appears twice in the iPhone's
*Discoverables* list. `PeerManager` de-duplicates by `displayName`; when
the same display name surfaces under a new `MCPeerID`, the stored entry is
**replaced** with the new one — the newer ID is the one MC will actually
route invitations through.

---

## SwiftData usage

The Mac is the source of truth for persistent data. Two `@Model` entities:

- `TaskRecord` — stores focus tasks. The iPhone receives them as value-type
  `TaskItem` snapshots over MC.
- `SessionRecord` — records every completed (or skipped) session, used for
  analytics.

```swift
@Model
public final class TaskRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var sortIndex: Int
}

@Model
public final class SessionRecord {
    @Attribute(.unique) public var id: UUID
    public var sessionTypeID: String
    public var sessionTitle: String
    public var startedAt: Date
    public var completedAt: Date
    public var plannedDuration: TimeInterval
    public var actualDuration: TimeInterval
    public var tasksCompleted: Int
    public var wasInterrupted: Bool
}
```

The `ModelContainer` is created in `SyncSpaceApp` and injected via
`.modelContainer(modelContainer)`. The host's `AppModel` calls
`attach(modelContext:)` once on launch to hydrate its in-memory cache.

---

## Synchronization flow

### 1. Discovery and pairing

```
iPhone                                   Mac
  │                                       │
  │── browse _syncspace._tcp ─────────────▶│ advertise _syncspace._tcp
  │                                       │
  │◀──────────────── found peer ──────────│
  │                                       │
  │── invitePeer ────────────────────────▶│
  │                                       │
  │◀──────── invitation accepted ─────────│
  │                                       │
  │── requestSnapshot ───────────────────▶│
  │                                       │
  │◀── timerUpdate, audioUpdate, tasks ───│
```

### 2. Steady-state messaging

The wire format is JSON-encoded `SyncMessage`:

```swift
public enum SyncMessage: Codable, Sendable {
    case timerUpdate(TimerState)
    case timerCompleted(SessionType)
    case audioUpdate(AudioMixState)
    case taskSnapshot([TaskItem])
    case sessionRecorded(plannedSeconds: Int, actualSeconds: Int, sessionTypeID: String)
    case command(RemoteCommand)
    case requestSnapshot
    case handshake(role: PeerRole, deviceName: String, appVersion: String)
}
```

- **Mac → iPhone** broadcasts are *reliable* (timer ticks, task updates) or
  *unreliable* (audio volume drags).
- **iPhone → Mac** commands always travel reliably so taps never get lost.

### 3. Conflict resolution

Mac always wins. The iPhone never mutates its own copy of timer state outside
of what it has just received; it only sends `RemoteCommand` messages. The Mac
executes the command authoritatively and re-broadcasts.

---

## Data models

```swift
public struct TimerState: Codable, Hashable, Sendable {
    public var sessionType: SessionType
    public var totalDuration: TimeInterval
    public var remainingTime: TimeInterval
    public var isRunning: Bool
    public var startedAt: Date?
    public var lastUpdated: Date
}

public struct AudioMixState: Codable, Hashable, Sendable {
    public var rainVolume: Float
    public var whiteNoiseVolume: Float
    public var cafeVolume: Float
    public var forestVolume: Float
    public var lofiVolume: Float
    public var masterVolume: Float
    public var isMasterMuted: Bool
}

public struct TaskItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var sortIndex: Int
}
```

All models are `Codable` + `Sendable` + `Hashable` value types — safe to send
across actors and across the wire.

---

## UI design philosophy

SyncSpace aims to feel like a first-party Apple app:

- **Calm by default.** A breathing gradient backdrop drifts in slow, low-amplitude
  loops. Movement only happens for purpose.
- **Glassmorphism, sparingly.** The custom `glassCard()` modifier uses
  `.ultraThinMaterial` over a deep dark backdrop with subtle radial highlights.
- **Premium type.** SF Rounded for the timer numerals, San Francisco for body
  copy. Generous spacing.
- **Native gestures.** Drag faders, swipe to delete, double-click to rename.
- **Motion has meaning.** The orb breathes only while the timer runs. The
  progress ring is the dominant motion when focusing — everything else stays
  still so it doesn't compete.

Brand palette (`AppTheme.swift`):

| Role          | Hex      | Usage                              |
|---------------|----------|------------------------------------|
| Electric Indigo | #6C5CF2 | Primary accent, timer ring         |
| Cyan          | #4DC6F5  | Secondary, links, sync indicators  |
| Mint          | #59ECBF  | Success, completion, streaks       |
| Plum          | #B86BEB  | Audio, ambient highlights          |
| Warning       | #FBB752  | Skip / interrupted state           |
| Error         | #F65C6A  | Mute / destructive                 |

---

## Accessibility

- **VoiceOver** — all custom controls use `accessibilityLabel` and
  `accessibilityValue` (see `CircularTimerView`).
- **Dynamic Type** — body copy uses SwiftUI text styles, not fixed font
  sizes.
- **Reduced Motion** — animations are short (`smooth(duration:)` defaults to
  ~0.4s) and the breathing background's amplitude is small. When iOS reports
  reduced motion, the system automatically dampens spring animations.
- **High Contrast** — interactive elements have visible stroke outlines on
  top of `.ultraThinMaterial`.
- **Keyboard Navigation** — Mac transport controls have keyboard shortcuts
  (Space to play/pause, ⌘P/⌘R/⌘.) declared via `CommandMenu`.

---

## Offline functionality

SyncSpace is **100% offline by design.**

- No HTTP, no WebSockets, no cloud sync.
- All persistence is local SwiftData on the Mac.
- Pairing uses Apple's Multipeer P2P Wi-Fi, which can fall back to Bluetooth
  if both devices have it enabled — useful on aircraft or in air-gapped
  environments.
- The iPhone caches whatever it received last so when the link drops, the
  dashboard keeps displaying meaningful state until reconnection.

---

## Performance considerations

- **Audio**: 22050-sample buffers (~0.5s @ 44.1kHz) generated on demand. Two
  buffers pre-scheduled per channel for zero gaps.
- **Networking**: timer updates broadcast at most every ~200ms; slider drags
  use `.unreliable` so stale frames are dropped, never queued.
- **Animations**: SwiftUI's `.smooth` springs run on the render thread.
  Heaviest visual (`BreathingBackground`) is two blurred gradients, not
  particles.
- **SwiftData**: only `TaskRecord` and `SessionRecord` are persisted.
  Analytics roll-ups happen on demand and cache results in `AppModel`.
- **Memory**: typically <60 MB on macOS, <40 MB on iPhone.

---

## Networking design

`PeerManager` is the only file that touches `MultipeerConnectivity`. It exposes:

- `start()` / `stop()` / `restart()` lifecycle methods. `restart()` exists so
  the in-Settings "Restart" button can do a single atomic teardown-and-rebuild
  rather than the stop-then-asyncAfter-start pattern earlier callers used
  (which left a window of stale MC state).
- `send(_:)` reliable and `sendUnreliable(_:)` for hot paths.
- `onReceiveMessage` callback invoked on `MainActor`.
- Observable status: `offline | advertising | browsing | connecting | reconnecting | connected`.

The MC delegate methods are `nonisolated` and hop back into MainActor for any
state mutation. The `MCSession` reference is held as a `nonisolated let` so it
is safe to read from the MC framework's internal queues.

### Connection state machine

Authoritative transitions:

```
offline ─▶ advertising / browsing ─▶ connecting ─▶ connected
                  ▲                       │            │
                  │                       ▼            ▼
                  └──── revertToIdle() ◀──┴── reconnecting (auto-rescheduled)
```

- `inFlightInviteTarget` + `connectingStartedAt` are tracked so we never
  pile two invites on top of each other and so we can recognise a stuck
  `.connecting` state.
- A **connecting ceiling** (12s) in the watchdog reverts a stuck
  `.connecting` back to idle. MC occasionally swallows `notConnected` after
  a silent handshake failure; without this ceiling the UI sat on
  "Connecting…" indefinitely.
- `lostPeer` clears the in-flight invite target if the lost peer is exactly
  the one we were trying to reach, so the watchdog can immediately re-target
  without waiting for the dead invite to time out.

### Timing constants

| Constant            | Value | Why                                                         |
|---------------------|------:|-------------------------------------------------------------|
| `heartbeatInterval` |  3.0s | Detects half-open sessions cheaply                           |
| `watchdogInterval`  |  3.0s | Re-invite cadence — short so a failed first invite re-fires |
| `inviteThrottle`    |  4.0s | A hair under `inviteTimeout` so we don't queue duplicates    |
| `inviteTimeout`     | 10.0s | Reasonable ceiling for the local network                     |
| `reconnectDelay`    |  0.8s | Snappy recovery after a dropped link                         |
| `connectingCeiling` | 12.0s | Hard limit on `.connecting` before revert                    |

---

## Audio engine

`AudioEngineService` is a custom AVAudioEngine pipeline. There is **no shipped
audio file** — every channel is procedurally synthesised:

| Track       | Synthesis technique                                                          |
|-------------|-------------------------------------------------------------------------------|
| Rain        | Pink noise via Paul Kellet's economy filter, low-passed, with rare impulses |
| White Noise | Uniform white noise                                                          |
| Cafe        | Brown noise (rumble) + high-passed pink (chatter) + sparse "cup clink" impulses |
| Forest      | Filtered pink wind with slow gust LFO + occasional fast-sweep "bird chirp"  |
| LoFi        | Layered sines forming an Am7 chord, slow tremolo, tape hiss, soft saturation |

Each channel runs through its own `AVAudioMixerNode` (for per-channel gain)
into the main mixer. Volume changes use a 12-step interpolated fade to avoid
zipper noise.

---

## Haptic system

`HapticManager` defines four event types backed by custom
`CHHapticPattern`s on iOS:

- `sessionStarted` — short transient + 0.18s continuous tail
- `sessionPaused` — single soft transient
- `sessionResumed` — slightly sharper transient than start
- `sessionCompleted` — distinctive *double-bloom* (transient → 0.4s
  continuous → final transient) so users feel completion across a desk

On macOS the manager falls back to `NSHapticFeedbackManager.alignment` so
trackpad-equipped users still get tactile cues.

---

## Theme system

Appearance is driven through **one channel only**: SwiftUI's
`.preferredColorScheme(...)`. The user's choice (`System`, `Light`, `Dark`)
is stored in `@AppStorage("syncspace.appearance")` and resolved by
`AppearanceModifier` at the Scene root.

### The single-channel rule

Earlier iterations drove appearance through two parallel channels —
`.preferredColorScheme(...)` *and* `NSApp.appearance` /
`UIWindow.overrideUserInterfaceStyle`. On macOS Tahoe this races:
`.preferredColorScheme(nil)` does not reliably invalidate a previously
stamped `.light` override, but `NSApp.appearance = nil` correctly clears.
The two paths diverged — window chrome followed the system while SwiftUI
views reading `@Environment(\.colorScheme)` stayed pinned. That is the
"window dark, cards light, materials mixed" symptom.

The current implementation removes the AppKit/UIKit bridge entirely and
pipes everything through `preferredColorScheme` with an **always-explicit**
value on macOS — never `nil` — so SwiftUI's invalidation path always sees
an explicit-to-explicit transition.

### `ThemeBridge`

`ThemeBridge` is a `@MainActor @Observable` singleton that KVO-observes
`NSApp.effectiveAppearance` on macOS and republishes a `ColorScheme`. When
the user picks System mode, `AppearanceModifier` reads
`ThemeBridge.shared.systemColorScheme` and passes it as the explicit
`preferredColorScheme` value. Live OS light/dark toggles propagate
automatically — the KVO callback re-fires, the bridge republishes, the
`@Observable` registrar invalidates `AppearanceModifier`, and the whole
view tree re-evaluates in lockstep.

### Propagation flow

```
AppStorage("syncspace.appearance")
        │
        ▼
AppearanceModifier.body
        │
        ├── .light   → resolved = .light
        ├── .dark    → resolved = .dark
        └── .system  → resolved = ThemeBridge.shared.systemColorScheme  (macOS)
                       resolved = nil                                    (iOS)
        │
        ▼
.preferredColorScheme(resolved)            (single channel)
        │
        ▼
@Environment(\.colorScheme) on every descendant
        │
        ▼
GlassCardStyle · PageHeaderCapsule · ConnectionBadge · chips
window chrome · materials  → all re-render together.
```

### Persistence

- `@AppStorage` survives relaunches.
- System mode survives relaunches and always re-reads the live OS
  appearance on launch via `ThemeBridge`.
- No view caches an appearance value. Custom colors that adapt
  (e.g. `GlassCardStyle`'s border opacity) read `@Environment(\.colorScheme)`
  directly so they re-evaluate when the env flips.

---

## Page header system

Every macOS destination (Focus Session, Tasks, Audio Mixer, Analytics,
Settings) gets the same centered title pill rendered by a single
`PageHeaderCapsule` view in `Shared/Components`. The component owns
typography, padding, material, corner radius, and minimum width, so no
screen can drift out of lock-step.

```swift
PageHeaderCapsule("Focus Session")
```

Internal sizing:

- Font: `.system(size: 14, weight: .semibold)` with `0.2` tracking.
- Horizontal padding: 32 pt per side.
- Vertical padding: 12 pt top, 11 pt bottom (asymmetric for optical
  centering — pulls the cap-height onto the geometric centre of the
  capsule).
- Minimum width: 168 pt so short titles ("Tasks", "Settings") still feel
  spacious.
- Background: `DS.Surface.chip` (`.ultraThinMaterial`) inside a
  `Capsule(style: .continuous)`.
- Border: 1 pt hairline at `Color.primary.opacity(scheme == .dark ? 0.10 : 0.08)`.
- Accessibility: `.accessibilityAddTraits(.isHeader)`.

### Why the capsule lives in content, not the toolbar

On macOS 26 (Tahoe) the unified toolbar auto-wraps `ToolbarItem(placement:
.principal)` content in its own Liquid Glass capsule. Adding a custom
capsule there produced a nested pill — visible outer border, inner border,
and two stacked materials. `MacRootView` therefore hosts
`PageHeaderCapsule` at the top of the detail content area instead, and the
window toolbar style is set to `.unified(showsTitle: false)` so the system
no longer renders a competing title chip:

```swift
detail: {
    VStack(spacing: 0) {
        PageHeaderCapsule(selection.navigationTitle)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xs)
        detailContent
    }
    .background(BreathingBackground(intensity: 0.35))
}
```

The result is one capsule per destination, fully under our control, with
no system chrome nesting around it.

---

## Demo walkthrough

A typical product demo:

1. **"Mac is the workspace."** Launch SyncSpace Hub. Show the four sidebar
   sections. Start a 25-minute Focus session. Point out the breathing glow.
2. **"Audio you can shape."** Open the Audio Mixer. Pull LoFi to 0.6, Rain to
   0.4, demonstrate that the engine renders them in real time.
3. **"Now plug in the iPhone."** Launch the Remote on a phone next to the
   laptop. Show the auto-pairing — the green badge appears within ~1 second.
4. **"Same session, two views."** Show the orb on the iPhone reacting to the
   audio energy and pulse. Tap pause on the phone — Mac pauses immediately.
5. **"Productivity glue."** Add a task on the phone. Watch it appear on the
   Mac instantly. Check it off on the Mac. Phone reflects it.
6. **"Completion feels right."** Skip the timer (or wait it out). Phone fires
   the double-bloom haptic. Mac records the session.
7. **"And the data follows."** Open Analytics. Show the bar chart for the
   week, the streak, and the session mix donut updating live.

---

## Recent hardening pass

A focused stabilisation pass landed before this README update. Highlights:

### UI

- **`PageHeaderCapsule`** added as the single shared page-title pill.
  Renders in content space — never in `.principal` — to avoid the
  double-capsule rendering caused by macOS 26 Tahoe wrapping toolbar items
  in its own Liquid Glass capsule. `windowToolbarStyle` switched to
  `.unified(showsTitle: false)` so the system no longer renders a competing
  title chip.
- **iOS keyboard never traps the user.** The Tasks composer used to
  re-focus the field after every submit, which kept the keyboard up
  forever. It now resigns on submit and is dismissable via
  `.scrollDismissesKeyboard(.interactively)`, a `simultaneousGesture`
  tap-outside, and a `ToolbarItemGroup(placement: .keyboard)` Done button.

### Theme

- **Theme is single-channel.** The `NSApp.appearance` /
  `UIWindow.overrideUserInterfaceStyle` bridge that raced
  `preferredColorScheme` is gone. `AppearanceModifier` now drives
  appearance through `.preferredColorScheme(...)` only, with an
  always-explicit value on macOS resolved by `ThemeBridge`.
- **`Light → System` works.** Previously this transition left the window
  chrome dark and the SwiftUI-managed cards/materials light. Fixed by the
  single-channel rewrite plus KVO observation of `NSApp.effectiveAppearance`.
  Live OS appearance toggles while the app is running also propagate
  correctly now.

### Networking

- **Duplicate Macs in the iPhone's *Discoverables*** fixed. Peers are now
  de-duplicated by `displayName`, and a fresh `MCPeerID` for an
  already-known name replaces the stored one (the newer ID is what MC
  routes invitations through across multiple transports).
- **Faster handshake.** `inviteTimeout` 15s → 10s, `watchdogInterval` 6s
  → 3s, `inviteThrottle` 8s → 4s, `reconnectDelay` 1.5s → 0.8s. Perceived
  connect time drops from ~5–15 s on a flaky first invite to ~1–3 s.
- **No more stuck `.connecting`.** A 12 s connecting-ceiling in the
  watchdog reverts the status to idle if MC swallows `notConnected` after
  a silent handshake failure. The watchdog then re-invites cleanly.
- **`MCEncryptionPreference` is `.none`** for a local-network productivity
  app — `.optional`/`.required` were stalling on the encryption
  negotiation on freshly paired devices.
- **`PeerManager.restart()`** added. The earlier
  `stop() → asyncAfter(0.25) → start()` pattern in Settings buttons left a
  brief window of stale MC state; the new method is atomic.

### Build status

Both targets build clean against macOS 26 / iOS 26 (verified with
`xcodebuild … -destination 'platform=macOS'` and
`… 'generic/platform=iOS Simulator'`).

---

## Known challenges

- **Procedural audio** is convincing on rain/noise/cafe but lofi is more of a
  cousin to a real track than a faithful loop. Easy upgrade path: replace
  the `SignalGenerator` cases with file-based `AVAudioPlayerNode` schedules.
- **App Sandbox + MultipeerConnectivity**: the macOS target ships with
  `ENABLE_INCOMING_NETWORK_CONNECTIONS` and `ENABLE_OUTGOING_NETWORK_CONNECTIONS`
  on, which is required for Bonjour discovery.
- **macOS Tahoe Liquid Glass nesting** — any custom pill placed inside
  `ToolbarItem(placement: .principal)` will render *inside* the system's
  own glass capsule. Future toolbar work should host visual chrome in
  content space, as the `PageHeaderCapsule` does today.

---

## Roadmap

- [ ] Apple Watch companion that mirrors the orb
- [ ] Live Activity / Dynamic Island integration for the timer
- [ ] WidgetKit timeline for "today so far"
- [ ] AppIntents + Siri Shortcuts (start a Focus session by voice)
- [ ] Focus filter integration so iOS auto-engages Do Not Disturb during
      a session
- [ ] iCloud sync of `SessionRecord` history (optional, opt-in)
- [ ] Apple Intelligence "wrap-up" summarisation of completed sessions

---

## Future enhancements

- **Real audio assets**: ship lossy `.m4a` loops for richer ambient tracks.
- **Multi-iPhone**: support multiple Remotes simultaneously (the MC layer
  already allows it, the UI just hasn't been pushed that direction).
- **iPad layout**: enable side-by-side split view (the project is already
  multi-platform; just needs UI polish for iPad regular size class).
- **Visualisation modes**: pluggable visualisation pipeline (orb / waveform
  ring / particle field / breathing gradient).

---

## Resume highlights

- Designed and built an entirely native, offline-first cross-device focus
  ecosystem on Apple's latest SDKs.
- Authored a custom AVAudioEngine signal-generation pipeline (pink/brown noise,
  filtered wind, chord-stack lofi) with no third-party audio assets.
- Implemented an authoritative-host sync protocol over MultipeerConnectivity
  with discriminated-union messaging, reliable + unreliable channels, and
  optimistic UI for sub-100ms response.
- Built a SwiftData persistence layer with custom analytics roll-ups and Swift
  Charts visualisations.
- Wrote custom CoreHaptics patterns and a fallback haptic manager that works
  across iOS and macOS.

---

## Interview talking points

- **"Why authoritative-host?"** Conflict resolution becomes trivial — Mac
  state always wins. The iPhone never owns the timeline, so two-device drift
  is impossible.
- **"Why MultipeerConnectivity instead of Bonjour + custom sockets?"** MC gives
  encrypted P2P transport, automatic discovery, peer disconnect handling, and
  graceful Bluetooth fallback for free. Replacing it with custom sockets would
  triple the surface area for ~zero user-facing benefit.
- **"How do you keep the UI responsive on a slider drag?"** Slider drags emit
  `RemoteCommand.setTrackVolume` over `.unreliable` MC, so frames can drop
  without queuing. Mac's `AudioEngineService` does a 100ms fade interpolation
  so the audio path is never the bottleneck.
- **"Why a single multi-platform target?"** Maximises code reuse for models,
  networking, audio, and analytics — only the views differ. SwiftUI's
  conditional compilation lets us keep platform-specific UI in clearly named
  files (`MacRootView`, `iOSRootView`) without separate targets.
- **"Why @Observable instead of ObservableObject?"** It only re-evaluates
  the views that actually read a property, dramatically reducing render work
  on every timer tick (every 200ms).

---

## Developer notes

- All view files start with `#if os(macOS)` or `#if os(iOS)` so the multi-platform
  target builds cleanly for either.
- The `MainActor` default isolation is set on the target (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
  Most of the codebase therefore reads as if it's UI-side; only MC delegate
  methods are explicitly `nonisolated`.
- The audio engine starts lazily on the Mac when the app launches and stops if
  you toggle it off in Settings.
- To clear all stored history, use Settings → Data → *Clear history*.
- **Theme propagation rule.** Drive appearance exclusively through
  `.preferredColorScheme(...)` at the Scene root via
  `appearancePreference()`. Do not call `NSApp.appearance =` or
  `UIWindow.overrideUserInterfaceStyle =` anywhere — those paths race the
  SwiftUI override and produce the mixed light/dark rendering this project
  has already debugged once.
- **Page header rule.** Use `PageHeaderCapsule` for any centered page-title
  pill, and place it in content space, not inside
  `ToolbarItem(placement: .principal)`. macOS Tahoe wraps principal
  toolbar items in its own glass capsule, which would re-nest the pill.

---

## Contributing

Contributions are welcome. Please open an issue describing the change before
sending a PR for non-trivial work. Coding conventions:

- 4-space indentation, Swift API design guidelines.
- Models stay value types, services stay `@Observable` reference types.
- Don't add internet dependencies — this is an offline-first app on purpose.

---

## License

MIT. See `LICENSE` for details.
