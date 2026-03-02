# 🔧 Skill: Backend (FastAPI + SQLAlchemy + PostgreSQL)

Use this skill whenever you're working on anything in the `backend/` directory.

---

## Stack
- **Framework**: FastAPI
- **ORM**: SQLAlchemy (async preferred)
- **Database**: PostgreSQL with pgvector extension
- **Migrations**: Alembic
- **Validation**: Pydantic v2
- **Auth**: JWT

---

## Architecture Pattern

Always follow this layered approach within `backend/app/`:

```
Request → Router (api/routers/) → Service (services/) → Model (models/) → DB
                                ↕
                         Schema (schemas/)   ← Pydantic in/out shapes
```

- **Routers** (`app/api/routers/`) handle HTTP concerns only: parsing input, calling a service, returning a response
- **Services** (`app/services/`) contain all business logic — no SQLAlchemy queries in routers
- **Models** (`app/models/`) are SQLAlchemy ORM definitions only — no business logic
- **Schemas** (`app/schemas/`) are Pydantic models for request bodies and response shapes
- **Core** (`app/core/`) config, DB connection, and auth setup
- **Alembic** (`alembic/`) all database migrations live here

---

## Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Route files | `snake_case.py` | `journal_entries.py` |
| Service files | `snake_case_service.py` | `entry_service.py` |
| Model classes | `PascalCase` | `JournalEntry` |
| Schema classes | `PascalCase + verb` | `JournalEntryCreate`, `JournalEntryResponse` |
| DB table names | `snake_case` plural | `journal_entries` |
| Route paths | `kebab-case` | `/journal-entries/{id}` |

---

## Adding a New API Endpoint

1. Create or update the Pydantic schema in `app/schemas/`
2. Add the service function in `app/services/`
3. Add the route in `app/api/routers/` — keep it thin
4. If it touches a new DB table or column → create an Alembic migration in `alembic/`
5. Write a test in `tests/`

**Route handler template:**
```python
@router.post("/journal-entries", response_model=JournalEntryResponse, status_code=201)
async def create_entry(
    payload: JournalEntryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await entry_service.create_entry(db, user_id=current_user.id, payload=payload)
```

---

## Adding a New DB Model

1. Create the SQLAlchemy model in `app/models/`
2. Import it in `app/models/__init__.py`
3. Review the generated migration in `alembic/versions/` — never blindly apply autogenerate


---

## Error Handling

- Use FastAPI's `HTTPException` for client errors (4xx)
- Use a global exception handler for unexpected server errors (5xx)
- Never expose SQLAlchemy or internal errors directly in responses
- Always log exceptions with context before re-raising

```python
# Good
raise HTTPException(status_code=404, detail="Journal entry not found")

# Bad
raise Exception(str(db_error))  # leaks internals
```

---

## Environment & Config

- Never hardcode secrets, URLs, or environment-specific values
- Use `.env` file locally, environment variables in production

---

## Testing Backend Code

Test files live in `tests/`. Use `pytest` + `httpx AsyncClient`.

```python
async def test_create_entry(client, auth_headers):
    response = await client.post(
        "/journal-entries",
        json={"content": "today I felt..."},
        headers=auth_headers,
    )
    assert response.status_code == 201
    assert "id" in response.json()
```

Run tests with:
```bash
cd backend && pytest tests/ -v
```
