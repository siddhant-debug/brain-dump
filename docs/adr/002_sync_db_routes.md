# ADR 002: Synchronous DB Routes

## Status
Accepted

## Context
FastAPI supports both `async def` and standard `def` for route handlers. While `async` is generally preferred for I/O, many of our database operations use SQLAlchemy's synchronous drivers (`psycopg`). Using `async def` with blocking database calls can starve the event loop.

## Decision
We will use **standard `def`** for routes that perform heavy, blocking database operations. FastAPI automatically executes these in an external thread pool, preventing blocking the main event loop.

## Consequences
- **Pros**: Better performance for CPU-bound or blocking I/O tasks (like reranking and large DB queries).
- **Cons**: Slightly higher memory overhead due to thread pool management.
