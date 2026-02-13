# Brain Dump Frontend Documentation

## 1. Architecture Overview
The frontend is built with **Flutter**, utilizing a feature-first folder structure and **Riverpod** for robust state management. It communicates with the FastAPI backend using **Dio** for networking.

### Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Flutter Riverpod (Providers, StateNotifiers, AsyncValue)
- **Networking**: Dio (with Interceptors & Options)
- **Local Storage**: Flutter Secure Storage (for JWT persistence)
- **UI Components**: Custom "Glassmorphism" widgets, Animated Builders, and a macOS-style Dock.

### Folder Structure
```text
lib/
├── main.dart             # App entry & ProviderScope
├── core/
│   ├── providers/        # Global singletons (e.g., dio_provider)
│   └── widgets/          # Reusable UI (MinimalIconButton, SynapticRoots)
├── features/
│   ├── auth/             # Login/Signup logic & UI
│   ├── brain_dump/       # Main input screen & Neural Tree visualization
│   ├── dock/             # Mac-style Zooming Dock logic
│   ├── notes/            # NoteService & Quick Save logic
│   └── vault/            # FileService & The Vault UI
└── screens/              # Top-level screen composites (BrainDumpScreen)
```

---

## 2. Key Providers & Services

| Provider | Type | Responsibility |
| :--- | :--- | :--- |
| `authControllerProvider` | `StateNotifierProvider` | Handles Login/Signup, stores JWT, manages Auth state. |
| `noteServiceProvider` | `Provider` | API client for the `/notes` endpoints. |
| `brainDumpProvider` | `StateNotifierProvider` | UI logic for the input field, processing state, and neural animations. |
| `filesProvider` | `FutureProvider` | Fetches the list of files for The Vault. |
| `dockProvider` | `StateNotifierProvider` | Manages the open/close state and animation of the Dock. |
| `dioProvider` | `Provider` | Configured Dio instance (BaseUrl, Timeouts). |

---

## 3. Interaction Flows (Sequence Diagrams)

### Flow A: User Authentication & Session
How the app establishes a session and maintains it.

```mermaid
sequenceDiagram
    participant UI as LoginScreen
    participant Auth as AuthController
    participant Store as SecureStorage
    participant API as FastAPI Backend

    UI->>Auth: login(email, password)
    Auth->>API: POST /auth/login
    API-->>Auth: 200 OK {access_token}
    Auth->>Store: write('jwt_token', token)
    Auth->>UI: State = Data(null) (Success)
    UI->>UI: Redirect to BrainDumpScreen
```

### Flow B: Quick Save (Saving a Thought)
The path a user's thought takes from input to the database.

```mermaid
sequenceDiagram
    participant UI as BrainDumpInput / SendBtn
    participant Prov as BrainDumpNotifier
    participant Svc as NoteService
    participant API as FastAPI Backend

    UI->>UI: User hits "Send"
    UI->>Prov: processInput(text)
    Prov->>Prov: state = isProcessing(true)
    Prov->>Svc: saveNote(text)
    Svc->>Svc: _getToken()
    Svc->>API: POST /notes/ [Auth Header]
    API-->>Svc: 201 Created
    Svc-->>Prov: Success
    Prov->>Prov: state = isProcessing(false)
    Prov-->>UI: Clear Input & Show SnackBar
```

### Flow C: Opening The Vault
Fetching data for the unified File/Note view.

```mermaid
sequenceDiagram
    participant UI as FileVaultScreen
    participant FileProv as filesProvider
    participant NoteProv as notesProvider
    participant API as FastAPI Backend

    UI->>FileProv: watch(filesProvider)
    UI->>NoteProv: watch(notesProvider)
    
    par Fetch Files
        FileProv->>API: GET /files/
    and Fetch Notes
        NoteProv->>API: GET /notes/
    end

    API-->>FileProv: List[StoredFile]
    API-->>NoteProv: List[Note]
    
    FileProv-->>UI: AsyncValue.data(files)
    NoteProv-->>UI: AsyncValue.data(notes)
    UI->>UI: Render TabBarView (Files | Thoughts)
```

---

## 4. State Management Strategy

The app uses **Riverpod** to separate UI from Logic.

1.  **UI Level**: Widgets like `BrainDumpScreen` watch providers. They react to changes (e.g., showing a spinner when `brainDumpProvider` is loading).
2.  **Logic Level**: `StateNotifier`s (like `BrainDumpNotifier`) hold the business logic. They mutate their state (e.g., `state = state.copyWith(isProcessing: true)`) which triggers UI rebuilds.
3.  **Data Level**: Services (like `NoteService`) are pure Dart classes that perform IO. They are injected into Notifiers via Ref.

### Data Flow Visualization
This layered approach ensures that the UI never directly touches the Network layer.

```mermaid
flowchart LR
    subgraph UI [Flutter UI]
        W[Widget]
    end

    subgraph Riverpod [State Management]
        P[Provider]
    end

    subgraph Logic [Data Layer]
        S[Service Class]
        D[Dio Client]
    end

    subgraph Backend [Server]
        API[FastAPI]
    end

    W -- "ref.read()" --> P
    P -- "returns instance" --> S
    S -- "GET / POST" --> D
    D -- "HTTP Request" --> API
```
