# BrainDump Frontend Documentation

## 1. Architecture Overview
BrainDump's frontend is a Flutter application based on the "Black Canvas" minimalist design philosophy. It prioritizes rapid entry and real-time feedback.

### Tech Stack
- **UI Framework**: Flutter (iOS Optimized)
- **State Management**: Riverpod (Strictly StateNotifier/Provider)
- **Networking**: Dio (Custom SSE interceptors for streaming)
- **Local Storage**: `flutter_secure_storage` for JWT and settings.
- **Asset/Theming**: Custom Glassmorphism and Neon accents via `AppTheme`.

## 2. Feature-First Folder Structure (`lib/features/`)
Each module encapsulates its own logic, UI, and data models:
- **brain_dump**: The primary interface for note capturing and chatting. 
  - *Logic*: Strictly mode-based via a toggle in the header. In **Journal Mode**, all inputs are captured as rapid notes with a "ghost" animation. In **Chat Mode**, all inputs are sent to the RAG engine as contextual queries.
- **analytics**: Real-time visualization of backend-derived insights.
- **vault**: A secure viewer for RAG-indexed documents.
- **health**: Native bridge for Apple HealthKit synchronization.
- **music**: Native bridge for Apple MusicKit playback and context.

## 3. Core Principles & Rules
From `rules.md`:
- **State Management**: Always use `StateNotifierProvider`, never `ChangeNotifier`.
- **Reactivity**: Use `ref.watch()` in `build`, avoid `ref.read()` where possible.
- **Lifecycle**: Every `StateNotifier` must implement `WidgetsBindingObserver` to handle app resume/pause (essential for background sync).

## 4. Native Platform Bridges
Communication with iOS is handled via `MethodChannel`:
- **HealthKit**: Queries for Heart Rate, HRV, Activity, and Sleep.
- **MusicKit**: Retrieves current playback state and music-user-token.
- **Navigation**: Deep linking and haptic feedback integration.

## 5. State Management & Data Flow
1. **Providers**: Dependency injection via Riverpod (e.g., `dioProvider`, `healthServiceProvider`).
2. **Controllers**: Business logic orchestration (e.g., `HealthSyncController` managing polling intervals).
3. **Services**: Abstract interfaces for platform-specific implementations.

## 6. Real-time Interaction (SSE)
The `BrainService` parses Server-Sent Events from the backend, yielding chunks to the `BrainDumpNotifier`. The UI uses these chunks to update a reactive list, providing the "Internal Monologue" typing effect.

## 7. Security
- **Auth Persistence**: JWT is stored in iOS Keychain via `flutter_secure_storage`.
- **Session Handling**: Automatically clears state on 401 response from any endpoint.
