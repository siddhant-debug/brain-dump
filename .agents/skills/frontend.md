# 📱 Skill: Frontend (Flutter)

Use this skill whenever you're working on anything in the `frontend/` directory.

---

## Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod (`flutter_riverpod`, `riverpod_annotation`)
- **API Client**: Dio
- **Local Storage**: FlutterSecureStorage

---

## Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Screen files | `snake_case_screen.dart` | `dashboard_screen.dart` |
| Widget files | `snake_case_widget.dart` | `entry_card_widget.dart` |
| Service files | `snake_case_service.dart` | `brain_service.dart` |
| Controller/Provider | `snake_case_controller.dart`| `auth_controller.dart` |
| Model files | `snake_case.dart` | `chat_message.dart` |
| Class names | `PascalCase` | `ChatMessage` |
| Variables/functions | `camelCase` | `fetchHistory()` |

---

## Adding a New Feature / Screen

This project uses a feature-first architecture with dedicated folders for logic and UI.

1. Create a new folder in `lib/features/<feature>/` if it's a major feature module.
   - Use subfolders: `models/`, `services/`, `providers/` (or `controllers/`), `presentation/`, `widgets/`
2. If it's a standalone screen, you can put it in `lib/screens/`
3. Add the screen to the app's navigation/routing.
4. If it needs API data → add a Service in `lib/features/<feature>/services/` and a Riverpod Provider in `lib/features/<feature>/providers/`
5. If it needs a new Dart model → add it in `models/` mirroring the backend schema

below is just example 
**Screen template:**
```dart
class JournalListScreen extends StatelessWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Journal')),
      body: const _JournalListBody(),
    );
  }
}

class _JournalListBody extends StatelessWidget {
  const _JournalListBody();

  @override
  Widget build(BuildContext context) {
    // use provider/riverpod/bloc here
    return const Placeholder();
  }
}
```

---

## API Service Pattern

All API calls go through services (e.g., `lib/features/<feature>/services/`). Never call Dio directly from a widget or screen. Provide the service to widgets via a Riverpod Provider.

below is just example 

```dart
// journal_service.dart
class JournalService {
  final ApiClient _client;

  JournalService(this._client);

  Future<List<JournalEntry>> getEntries() async {
    final response = await _client.get('/journal-entries');
    return (response.data as List)
        .map((e) => JournalEntry.fromJson(e))
        .toList();
  }

  Future<JournalEntry> createEntry(String content) async {
    final response = await _client.post(
      '/journal-entries',
      data: {'content': content},
    );
    return JournalEntry.fromJson(response.data);
  }
}
```

---

## Dart Models

Dart models should mirror backend Pydantic response schemas exactly.
below is just example 
```dart
class JournalEntry {
  final String id;
  final String content;
  final DateTime createdAt;

  const JournalEntry({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'created_at': createdAt.toIso8601String(),
  };
}
```

> ⚠️ When a backend response schema changes, update the Dart model too.

---

## Widget Rules

- Keep widgets small — if a `build()` method exceeds ~80 lines, split it
- Extract locally reused widgets into `lib/features/<feature>/widgets/`
- Extract globally reused widgets into `lib/core/widgets/`
- Never put business logic in widgets — use Controllers/Providers
- Prefer `const` constructors wherever possible for performance
- Use named constructors for widget variants rather than many boolean params

---

## Error Handling in UI

- Never show raw error messages to users
- Show user-friendly error states with retry options
- Log errors to console in debug mode
- Handle loading, error, and empty states for every data-fetching widget

---

## Testing Flutter

Smoke tests live in `tests/flutter/` (or `frontend/test/`).

```bash
cd frontend && flutter test
```

Tests should cover:
- Screens render without crashing
- Key widgets display correct data
- API service calls fire correctly (use mocks)
- Navigation routes work
