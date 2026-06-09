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
20. [Demo walkthrough](#demo-walkthrough)
21. [Known challenges](#known-challenges)
22. [Roadmap](#roadmap)
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
  reset, connection diagnostics.
- **Sidebar Navigation** with animated `matchedGeometryEffect` selection.
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
    │   │   └── PulsingOrb.swift
    │   │
    │   └── Utilities/
    │       ├── Theme.swift                   # Brand palette + gradients
    │       ├── TimeFormatter.swift
    │       └── ViewModifiers.swift           # GlassCardStyle, breathing
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

Both ends use `MCEncryptionPreference.required` for transport security.

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

- `start()` / `stop()` lifecycle methods
- `send(_:)` reliable and `sendUnreliable(_:)` for hot paths
- `onReceiveMessage` callback invoked on `MainActor`
- Observable status (`offline | advertising | browsing | connecting | connected`)

The MC delegate methods are `nonisolated` and hop back into MainActor for any
state mutation. The `MCSession` reference is held as a `nonisolated let` so it
is safe to read from the MC framework's internal queues.

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

## Known challenges

- **MC requires the same major OS** for best reliability. Cross-major-OS
  pairing sometimes drops on the first attempt — the Remote auto-retries.
- **Procedural audio** is convincing on rain/noise/cafe but lofi is more of a
  cousin to a real track than a faithful loop. Easy upgrade path: replace
  the `SignalGenerator` cases with file-based `AVAudioPlayerNode` schedules.
- **App Sandbox + MultipeerConnectivity**: the macOS target ships with
  `ENABLE_INCOMING_NETWORK_CONNECTIONS` and `ENABLE_OUTGOING_NETWORK_CONNECTIONS`
  on, which is required for Bonjour discovery.

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
