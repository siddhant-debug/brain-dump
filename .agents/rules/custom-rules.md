---
trigger: always_on
---

# 🧠 BrainDumps — Agent Rules & Guardrails

Read this before every task. These are non-negotiable.

---

## 📁 Actual Project Structure

```
backend/
├── app/
│   ├── api/
│   │   └── routers/
│   │       ├── analytics.py
│   │       ├── auth.py
│   │       ├── files.py
│   │       ├── notes.py
│   │       └── rag.py
│   ├── core/
│   │   ├── database.py
│   │   └── limiter.py
│   ├── models/
│   │   └── models.py          ← ALL SQLAlchemy models live here
│   ├── schemas/
│   │   └── schemas.py         ← ALL Pydantic schemas live here
│   ├── services/
│   │   └── rag_engine.py      ← RAG logic lives here
│   └── main.py
├── scripts/
│   ├── migrate_history.py
│   └── rebuild_brain.py       ← Re-indexing script, handle with care
└── postgres_data/

frontend/lib/
├── core/
│   ├── constants/             ← App-wide constants, colors, strings
│   ├── providers/             ← Shared providers
│   ├── theme/                 ← App theme
│   └── widgets/               ← Shared widgets used across features
├── features/
│   ├── analytics/
│   ├── auth/
│   ├── brain_dump/
│   ├── dock/
│   ├── music/
│   ├── notes/
│   ├── onboarding/
│   └── vault/
├── screens/                   ← Top-level screen files
│   ├── brain_dump_screen.dart
│   ├── dashboard_screen.dart
│   └── neural_canvas_page.dart
├── widgets/
│   └── neural_thread_background.dart
└── main.dart
```

---

## 🔴 NEVER Do These

### Backend / DB
- NEVER add a SQLAlchemy model anywhere except `app/models/models.py`
- NEVER add a Pydantic schema anywhere except `app/schemas/schemas.py`
- NEVER change DB schema without a proper migration script in `scripts/`
- NEVER change embedding logic in `rag_engine.py` without running RAG tests first
- NEVER run `rebuild_brain.py` without backing up pgvector data first
- NEVER put business logic inside router files — routers call services only
- NEVER remove or rename a route without checking all Flutter `services/` files for usages
- NEVER change a response shape without updating the corresponding Dart model in the feature folder

### Flutter
- NEVER put feature-specific code in `lib/screens/` — screens wire features together, they don't own logic
- NEVER put feature-specific code in `core/` — core is shared infrastructure only
- NEVER duplicate a widget already in `core/widgets/` or `lib/widgets/`
- NEVER call the API directly from a widget — always go through the feature's `services/` layer
- NEVER create a new feature outside of `features/`

---

## 🟢 ALWAYS Do These

### Before Starting Any Task
- Read the relevant skill file(s) for what you're touching
- Check if `models.py` or `schemas.py` already has what you need before adding new ones
- Identify which feature folder(s) in Flutter are involved

### While Coding
- Keep router handlers thin — one service call, return the result
- Each feature folder only contains what it needs: `models/`, `widgets/`, `providers/`, `services/` as required
- Reusable Flutter code → `core/widgets/`, not inside a feature folder
- Constants, colors, API base URLs → `core/constants/`

### Before Finishing
- Run the pre-merge workflow: `.antigravity/workflows/pre-merge.md`
- Summarize: which files changed, any schema changes, any new routes

---

## 🧩 Which Skill to Use

| Area | Skill File |
|------|-----------|
| Routers, models.py, schemas.py, database.py, limiter.py | `.antigravity/skills/backend.md` |
| rag_engine.py, rebuild_brain.py, pgvector queries | `.antigravity/skills/rag.md` |
| features/, screens/, core/, widgets/ | `.antigravity/skills/frontend.md` |

---

## 🔄 Which Workflow to Use

| Situation | Workflow File |
|-----------|--------------|
| Adding a new feature | `.antigravity/workflows/new-feature.md` |
| Before merging | `.antigravity/workflows/pre-merge.md` |
| Something is broken | `.antigravity/workflows/debugging.md` |
