# 🔐 BrainDump — Pre-App Store Security Audit

> **Audit Date:** February 20, 2026  
> **Status: ANALYSIS ONLY — No changes made.**  
> **Scope:** Python FastAPI Backend + Flutter Frontend

---

## 🔴 CRITICAL Issues

---

### CRIT-1 — Live Gemini API Key Committed to Git History
**File:** `backend/.env` → committed in `git` as of commit `799800f`  
**Specifically:** `git show HEAD:backend/.env` reveals:
```
GEMINI_API_KEY=AIzaSyAVtbrZWAYIivLzygrHfKMsQYB4DG5M35A
```
(A different key also exists in the current local `.env` — `AIzaSyDAj3W...` — so likely two rotations have happened, but the older key is now **permanently in git history on `origin/main`**.)

**Risk:** Anyone with read access to the GitHub repo can retrieve this key and use your Gemini quota, generate content on your bill, or enumerate your API usage. Git history never auto-deletes — even after adding `.env` to `.gitignore`, the key remains accessible via `git log` and `git show`.

**Fix:** Immediately revoke both keys from Google Cloud Console. Generate a new key. Use `git filter-repo` or BFG Repo Cleaner to purge the credential from all history, then force-push. Never commit `.env` files — use `.env.example` with dummy values.

---

### CRIT-2 — Database Password Hard-Coded as a Fallback in Source Code
**File:** `backend/app/core/database.py`, **Line 10**
```python
SQL_DB_URL = os.getenv("DATABASE_URL", "postgresql+psycopg://postgres:password123@127.0.0.1/postgres")
```

**Risk:** The password `password123` is baked into the source code as a default. If `DATABASE_URL` is unset in any environment (staging, CI/CD, Docker), the app silently uses this weak fallback — granting full DB access. This is also committed to your git history on `origin/main`.

**Fix:** Remove the fallback entirely. Raise an explicit `ValueError` if `DATABASE_URL` is not set. Never put credentials as default values.

---

### CRIT-3 — JWT Secret Key Hard-Coded in Source Code
**File:** `backend/app/api/routers/auth.py`, **Line 15**
```python
SECRET_KEY = "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7"
```
The comment even says: `# (In production, use environment variables)` — the fix was noted but never applied.

**Risk:** Any attacker who reads the source code (or your public GitHub repo) can forge valid JWT tokens for any user ID, gaining full access to any account's data, notes, uploads, and chat history.

**Fix:** Move to `os.getenv("JWT_SECRET_KEY")`. Raise `ValueError` if missing. Rotate immediately in production.

---

### CRIT-4 — Personal / Sensitive User Documents Left in Project Root & Uploads
**Paths found:**
```
./temp_5_luciano-ramalho-fluent-python_..._2022.pdf  (16MB — untracked)
./backend/uploads/5_BilledStatements_6715_13-03-25_13.37.pdf
./backend/uploads/5_Deep's Resume.pdf
./backend/uploads/5_Phase_3_OOP.pdf
```

**Risk:** Billing statements and résumés of real people are sitting in the uploads directory of a codebase being pushed toward an App Store launch. If `backend/uploads/` is inadvertently committed or the server directory is traversable, these files are exposed. The `temp_*.pdf` pattern in the root was created by the upload endpoint itself (`rag.py` line 31) and not reliably cleaned up.

**Fix:** Add `backend/uploads/` and `temp_*.pdf` to `.gitignore`. Confirm they are never committed. Implement temp file cleanup in a `finally` block to guarantee deletion even on error.

---

## 🟠 HIGH Issues

---

### HIGH-1 — No File Upload Size Limit (DoS / Storage Exhaustion)
**File:** `backend/app/api/routers/rag.py`, **Lines 16–135**; `backend/app/api/routers/files.py`, **Lines 18–56**

There is no `max_size` check, no `Content-Length` validation, and no size limit middleware anywhere in `main.py`. `file_content = await file.read()` will buffer the entire file into memory.

**Risk:** Any authenticated user can upload a multi-GB file, crashing the server with OOM or filling the disk. A single malicious user can take down the entire service (denial of service). Also, the `file_size` stored in DB uses `file.size if hasattr(file, 'size') else 0` — this is unreliable and easily bypassed.

**Fix:** Add `MAX_UPLOAD_SIZE = 50 * 1024 * 1024` (50MB). Check `len(file_content) > MAX_UPLOAD_SIZE` immediately after read, and reject with HTTP 413. Consider streaming upload to disk instead of full in-memory read.

---

### HIGH-2 — No File Type Validation (MIME Spoofing / Path Traversal)
**File:** `backend/app/api/routers/rag.py`, **Lines 41–62**

```python
filename_lower = file.filename.lower()
if filename_lower.endswith(".pdf"):
    ...
elif filename_lower.endswith((".txt", ".md", ".json", ".py", ".dart", ...)):
```

The file type is checked by extension only — **not by actual MIME type or magic bytes**. `file.content_type` is passed directly from the HTTP request, which a client can fully spoof.

**More critically**, `file.filename` from the client is used directly to construct disk paths:
```python
# files.py:40
file_path = os.path.join(UPLOAD_DIR, f"{current_user.id}_{filename}")
# rag.py:31
temp_path = f"temp_{current_user.id}_{file.filename}"
```

**Risk:** A filename like `../../etc/passwd` or `../../main.py` could overwrite arbitrary files on the server. A file named `evil.sh.pdf` passes the extension check but contains executable code.

**Fix:** Use `pathlib.Path(file.filename).name` to strip path components (never trust `..`). Validate actual MIME type using `python-magic`. Sanitize filenames to alphanumeric + safe characters only. Generate UUID-based storage filenames rather than user-provided names.

---

### HIGH-3 — CORS is Fully Open with Credentials Allowed
**File:** `backend/app/main.py`, **Lines 19–25**
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],       # ← Open to ALL origins
    allow_credentials=True,    # ← AND allows credentials
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Risk:** `allow_origins=["*"]` combined with `allow_credentials=True` is a **CORS misconfiguration** that allows any website in the world to make credentialed requests to your API from a user's browser. This enables CSRF-style attacks from malicious websites. Notably, browsers actually block this combination by spec — so this will also cause `fetch` to fail from web clients (a functional bug, not just a security one).

**Fix:** Before shipping, set `allow_origins` to your explicit production domain (e.g., `["https://yourdomain.com"]`). You cannot use `"*"` and `allow_credentials=True` simultaneously.

---

### HIGH-4 — No Rate Limiting on Any Endpoint
**File:** All routers — `auth.py`, `rag.py`, `notes.py`, `files.py`

None of the endpoints have any form of rate limiting middleware, IP throttling, or per-user request quotas.

**Risk:**
- `/auth/login` → Password brute-force with no lockout
- `/auth/signup` → Account creation spam
- `/chat/chat` → Each request triggers a Gemini API call; an attacker can burn your entire Gemini quota with concurrent requests
- `/chat/upload-to-brain` → Repeated large file uploads with no throttle

**Fix:** Add `slowapi` (FastAPI-compatible rate limiter). Apply `@limiter.limit("5/minute")` to `/auth/login`, `@limiter.limit("100/hour")` to `/chat/chat`, etc.

---

### HIGH-5 — BM25 Index is Shared Across All Users (Data Isolation Bug)
**File:** `backend/app/services/rag_engine.py`, **Lines 460–498**

```python
_bm25_model = None          # Global, shared across all users
_bm25_doc_registry = {}     # All users' documents in one index
_bm25_doc_content = {}      # All users' content in one dict
_bm25_doc_metadata = {}     # All users' metadata in one dict
```

The BM25 index is a **global in-memory structure that contains documents from all users**. The `user_id` filtering at line 538 is a secondary check done after scoring — `doc_scores` is computed across every document from every user before filtering.

**Risk:** Although the final results filter by `user_id`, this is a fragile boundary. Any bug in the metadata check would leak one user's documents to another user's results — a privacy violation in a multi-tenant app.

**Fix:** Either shard BM25 by user (`_bm25_models: dict[int, BM25Okapi]`) or accept vector-only retrieval for now and defer BM25 to a post-launch enhancement with proper per-user isolation.

---

### HIGH-6 — Internal Errors Exposed to Clients
**File:** `backend/app/api/routers/rag.py`, **Line 135**
```python
raise HTTPException(status_code=500, detail=str(e))
```
**Also:** `rag.py` Line 222 (streaming error):
```python
yield f"data: {json.dumps({'error': str(e), 'done': True})}\n\n"
```

**Risk:** Raw Python exception messages (stack traces, file paths, SQL errors, internal variable names) are sent directly to the client. An attacker can use these to map your server's internal structure, library versions, and database schema.

**Fix:** Log the full exception server-side using Python's `logging` module. Return a generic `"An internal error occurred."` to clients in all 500 responses.

---

## 🟡 MEDIUM Issues

---

### MED-1 — No Password Strength Enforcement
**File:** `backend/app/schemas/schemas.py`, **Line 11**

```python
class UserCreate(UserBase):
    password: str   # ← Any string accepted, no length/complexity rules
```

**Risk:** Users can set passwords like `a` or `1`. Combined with no rate limiting on login (HIGH-4), this makes brute-force trivial.

**Fix:** Add a Pydantic validator: `@validator('password')` checking minimum 8 characters, at least one number or special character.

---

### MED-2 — JWT Tokens Never Expire in Practice (7-Day Lifetime, No Revocation)
**File:** `backend/app/api/routers/auth.py`, **Line 17**
```python
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week
```

There is no token revocation list, no refresh token mechanism, and no server-side blocklist. Signing out on Flutter (`auth_controller.dart:196`) only deletes the token from device storage — **the actual JWT remains valid on the server for up to 7 days**.

**Risk:** If a JWT is stolen (via MITM, device backup, log leakage), the attacker has a full week of access with no way to invalidate it.

**Fix:** Reduce expiry to 15–60 minutes. Implement refresh tokens. Or, for a simpler short-term fix, maintain a server-side token blocklist on logout.

---

### MED-3 — Chat History Endpoint Has No Hard Pagination Cap
**File:** `backend/app/api/routers/rag.py`, **Lines 247–256**
```python
def get_chat_history(
    ...
    limit: int = 50     # ← User-controlled query param, no maximum enforced
):
    .limit(limit).all()
```

**Risk:** A client can request `GET /chat/history?limit=1000000`, causing a massive DB query that returns all conversation history in one response — potentially MB/GB of data, straining DB and memory.

**Fix:** Enforce a hard cap: `limit = min(limit, 100)`. Add offset-based pagination.

---

### MED-4 — Plaintext Logging of User Emails, Queries, and Filenames (PII Leakage)
**File:** `backend/app/api/routers/rag.py`, **Lines 147–148**
```python
print(f"[DEBUG] User: {current_user.email} (ID: {current_user.id})")
print(f"[DEBUG] Query: {request.query}")
```
**Also:** `rag.py:25–28`, `brain_service.dart:92`

**Risk:** In production, `print()` writes to server logs which may be stored by cloud providers or monitoring tools. User emails, personal thought content, and filenames become PII logged in plaintext — a potential GDPR/privacy violation.

**Fix:** Replace all `print()` with Python's `logging` module. Set log level to `DEBUG` only in development. Redact or omit PII (email, query content) from production log output. Add `LOG_LEVEL=INFO` to environment config.

---

### MED-5 — API Base URL Hard-Coded to `localhost` over Plain HTTP (App Store Blocker)
**File:** `lib/core/constants/api_constants.dart`, **Lines 8–17**
```dart
return 'http://localhost:8000';   // Web/iOS Simulator
return 'http://10.0.2.2:8000';   // Android Emulator
```

**Risk:** Both are `http://` (plaintext). Apple's App Transport Security (ATS) requires HTTPS for all connections in App Store builds — this is a likely App Store rejection. On real devices over real networks, JWT tokens and user data travel in plaintext, enabling MITM attacks.

**Fix:** Add a production URL via `--dart-define=API_URL=https://api.yourdomain.com`. Use HTTPS exclusively in production builds. Update `ApiConstants` to read from the environment variable.

---

### MED-6 — `profile_pic` Accepts Arbitrary Unvalidated URLs
**File:** `backend/app/schemas/schemas.py`, **Line 8**; `backend/app/api/routers/auth.py`, **Line 76**
```python
profile_pic: Optional[str] = None  # ← Unvalidated, stored in DB, returned to clients
```

**Risk:** A user could store an arbitrary URL as `profile_pic`. If Flutter renders it in `Image.network()`, it can be used to load tracking pixels or exfiltrate context via Referer headers. Server-Side Request Forgery (SSRF) is possible if the backend ever fetches that URL.

**Fix:** Validate that `profile_pic` is a well-formed HTTPS URL from a trusted domain, or implement a dedicated avatar upload endpoint and store only the internal path.

---

### MED-7 — Temp Files Not Guaranteed to be Cleaned Up on All Error Paths
**File:** `backend/app/api/routers/rag.py`, **Lines 31–135**

```python
temp_path = f"temp_{current_user.id}_{file.filename}"
with open(temp_path, "wb") as buffer:
    shutil.copyfileobj(file.file, buffer)
# Cleanup happens in happy path and except block, but NOT on OS-level kill signals
```

**Risk:** If the server crashes mid-request (OOM kill, power failure), temp files persist in the current working directory (next to app code) indefinitely. Over time this accumulates user data outside of controlled storage.

**Fix:** Use `tempfile.NamedTemporaryFile(delete=False)` inside a `try/finally` block. Store temp files in `tempfile.gettempdir()`. Guarantee cleanup in `finally`.

---

### MED-8 — No Input Length Validation on Notes or Chat Queries
**File:** `backend/app/schemas/schemas.py`, **Lines 45–48, 58–60**
```python
class NoteCreate(BaseModel):
    content: str        # ← No max length

class ChatRequest(BaseModel):
    query: str          # ← No max length
```

**Risk:** A user can send a 10MB string as a note or query. This can exhaust Gemini's input token limit, create bloated vector chunks, degrade retrieval quality, and cause unbounded memory usage during chunking.

**Fix:** Add Pydantic field constraints: `content: str = Field(..., max_length=50000)`, `query: str = Field(..., max_length=2000)`.

---

### MED-9 — `isAuthenticatedProvider` Checks Token Existence, Not Token Validity
**File:** `lib/features/auth/controllers/auth_controller.dart`, **Lines 25–29**
```dart
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final token = await storage.read(key: 'jwt_token');
  return token != null;   // ← Only checks presence, not expiry
});
```

**Risk:** A locally stored expired JWT token keeps `isAuthenticatedProvider` returning `true`, so the app routes the user to the main dashboard — but every actual API call fails with 401. The user experience degrades silently rather than prompting re-login.

**Fix:** Decode the JWT client-side (without verifying signature) to check the `exp` claim. If expired, delete the token and return `false`.

---

## 📋 Summary Table

| ID | Severity | Issue | File |
|----|----------|-------|------|
| CRIT-1 | 🔴 Critical | API key in git history | `backend/.env` (committed) |
| CRIT-2 | 🔴 Critical | DB password hard-coded as default | `database.py:10` |
| CRIT-3 | 🔴 Critical | JWT secret hard-coded in source | `auth.py:15` |
| CRIT-4 | 🔴 Critical | Personal docs exposed in repo/disk | `uploads/`, project root |
| HIGH-1 | 🟠 High | No file upload size limit | `rag.py:16-135`, `files.py:24` |
| HIGH-2 | 🟠 High | Path traversal + MIME spoofing | `rag.py:31`, `files.py:40` |
| HIGH-3 | 🟠 High | CORS open + credentials = misconfiguration | `main.py:19-25` |
| HIGH-4 | 🟠 High | No rate limiting anywhere | All routers |
| HIGH-5 | 🟠 High | BM25 index shared across all users | `rag_engine.py:460-498` |
| HIGH-6 | 🟠 High | Raw exceptions leaked to client | `rag.py:135`, `rag.py:222` |
| MED-1 | 🟡 Medium | No password strength enforcement | `schemas.py:11` |
| MED-2 | 🟡 Medium | 7-day JWT with no server revocation | `auth.py:17` |
| MED-3 | 🟡 Medium | Unbounded `limit` on chat history | `rag.py:248` |
| MED-4 | 🟡 Medium | PII (email, query) logged in plaintext | `rag.py:147-148` |
| MED-5 | 🟡 Medium | HTTP not HTTPS — ATS will block App Store | `api_constants.dart:8-17` |
| MED-6 | 🟡 Medium | Unvalidated `profile_pic` URL | `schemas.py:8`, `auth.py:76` |
| MED-7 | 🟡 Medium | Temp files not cleaned up on crash | `rag.py:31-135` |
| MED-8 | 🟡 Medium | No input length limits on notes/queries | `schemas.py:45-60` |
| MED-9 | 🟡 Medium | Auth checks token existence, not expiry | `auth_controller.dart:25-29` |

---

## ⛔ Verdict

**Do NOT submit to the App Store yet.**

The four CRITICAL items are hard blockers. **CRIT-1 requires immediate action regardless of anything else** — the Gemini API key in `origin/main`'s git history needs to be revoked *right now* from the Google Cloud Console, before doing anything else.

### Recommended Fix Order
1. 🔴 Revoke exposed API keys (CRIT-1) — **do this now, off-keyboard**
2. 🔴 Move all secrets to env vars (CRIT-2, CRIT-3)
3. 🔴 Clean sensitive files from disk and `.gitignore` uploads (CRIT-4)
4. 🟠 Add rate limiting (HIGH-4) — prevents quota theft and brute-force
5. 🟠 Fix CORS (HIGH-3) — required for any web client to work correctly
6. 🟠 Add file upload validation and size limits (HIGH-1, HIGH-2)
7. 🟠 Fix error exposure (HIGH-6)
8. 🟡 Switch to HTTPS (MED-5) — required for App Store ATS compliance
9. 🟡 Remaining medium issues at your discretion pre-launch
