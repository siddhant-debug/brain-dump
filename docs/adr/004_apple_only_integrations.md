# ADR 004: Apple-Only Native Integrations

## Status
Accepted

## Context
BrainDump targets high-performing individuals who largely use the Apple ecosystem. Supporting cross-platform (Android) Health/Music services early on would introduce significant development fragmentation.

## Decision
Focus exclusively on **iOS native frameworks**:
- **HealthKit** via Swift MethodChannels.
- **MusicKit** for primary playback and context data.
- **iCloud Keychain** for secure JWT storage.

## Consequences
- **Pros**: Deep, premium integration with the user's primary hardware (Apple Watch, AirPods).
- **Cons**: No immediate Android support.
