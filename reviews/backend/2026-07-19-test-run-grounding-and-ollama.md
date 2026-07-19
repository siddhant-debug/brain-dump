# Backend test run — 2026-07-19

Context: verifying the uncommitted grounding-score change (`rag.py` + `rag_engine.py`) is safe to merge, before wiring in the pluggable Ollama provider (`llm_service.py` / `ollama_service.py`). Run with `pytest tests/ -v` from `backend/`, using the project's `.venv` (`brain-dump/.venv`).

**Result: 49/49 core-suite tests passed** (the original 47 + 2 new Ollama tests), 0 failed, 0 skipped — re-verified directly (not just re-stated from the earlier run). Plus a separate 4/4 for the grounding-score eval below, for **53/53 total** across everything this session touched.

Every row below passed — "Expected" is the assertion the test makes; "Actual" is what the code actually produced this run. Where the test result is boolean/status-code-only, actual = expected (the run wouldn't be green otherwise). Where the code computes a specific value (e.g. tone label), the actual computed value is shown.

## Index (49 core-suite cases + 4 grounding-eval cases)

Jump to a section below for full input/expected/actual detail. **Meaningful** = would this test actually catch a real regression, or does it pass by construction? (`Yes` / `Shallow` = mocked-away, only checks status code or echoes input / `Stub` = placeholder, cannot fail)

| # | Test | File section | Meaningful? |
|---|------|------|------|
| 1 | `test_notes_flow` | [test_api_e2e.py](#teststest_api_e2epy-3--live-testclient-hitting-a-real-signuploginnotesfilesrag-flow) | Yes |
| 2 | `test_files_flow` | [test_api_e2e.py](#teststest_api_e2epy-3--live-testclient-hitting-a-real-signuploginnotesfilesrag-flow) | Yes |
| 3 | `test_rag_chat_flow` | [test_api_e2e.py](#teststest_api_e2epy-3--live-testclient-hitting-a-real-signuploginnotesfilesrag-flow) | Shallow — doesn't check answer correctness |
| 4 | `test_root_returns_200` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Yes |
| 5 | `test_signup_returns_200` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — DB mocked |
| 6 | `test_login_returns_token` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — auth funcs patched to fixed return |
| 7 | `test_protected_route_without_token_returns_401` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Yes |
| 8 | `test_notes_create_and_list` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — DB mocked |
| 9 | `test_files_list_returns_200` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — status only |
| 10 | `test_analytics_consistency_returns_200` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — status only |
| 11 | `test_nlp_parse_reminder_with_mock_gemini` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — Gemini mocked |
| 12 | `test_nlp_parse_reminder_too_long_returns_400` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Yes |
| 13 | `test_health_context_endpoint_returns_200` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — status only |
| 14 | `test_music_context_endpoint_returns_200` | [test_api_routes.py](#teststest_api_routespy-11--mocked-db-testclient-route-tests) | Shallow — tone analysis mocked |
| 15 | `test_valid_jwt_allows_access` | [test_core_auth.py](#teststest_core_authpy-4--jwt-auth-unit-tests) | Yes |
| 16 | `test_expired_jwt_returns_401` | [test_core_auth.py](#teststest_core_authpy-4--jwt-auth-unit-tests) | Yes |
| 17 | `test_tampered_jwt_returns_401` | [test_core_auth.py](#teststest_core_authpy-4--jwt-auth-unit-tests) | Yes |
| 18 | `test_missing_authorization_header_returns_401` | [test_core_auth.py](#teststest_core_authpy-4--jwt-auth-unit-tests) | **Stub** — `assert True` |
| 19 | `test_database_connection` | [test_core_database.py](#teststest_core_databasepy-3--postgrespgvector-connectivity) | Yes |
| 20 | `test_pgvector_extension_exists` | [test_core_database.py](#teststest_core_databasepy-3--postgrespgvector-connectivity) | Yes |
| 21 | `test_engine_disposal` | [test_core_database.py](#teststest_core_databasepy-3--postgrespgvector-connectivity) | Shallow — not-None check only |
| 22 | `test_gemini_chat_streaming` | [test_services_gemini.py](#teststest_services_geminipy-3--gemini-streamingerrornlp-now-routed-through-the-new-llm_service-factory-still-resolving-to-the-same-geminiservice-singleton-by-default) | Yes |
| 23 | `test_gemini_error_handling` | [test_services_gemini.py](#teststest_services_geminipy-3--gemini-streamingerrornlp-now-routed-through-the-new-llm_service-factory-still-resolving-to-the-same-geminiservice-singleton-by-default) | Yes |
| 24 | `test_nlp_parsing_with_gemini` | [test_services_gemini.py](#teststest_services_geminipy-3--gemini-streamingerrornlp-now-routed-through-the-new-llm_service-factory-still-resolving-to-the-same-geminiservice-singleton-by-default) | **Stub** — empty `pass`, no assertion |
| 25 | `test_rag_ingestion_chunks_text` | [test_services_rag.py](#teststest_services_ragpy-7--rag-engine-unitintegration-tests) | Yes |
| 26 | `test_rag_dense_embed_returns_vector` | [test_services_rag.py](#teststest_services_ragpy-7--rag-engine-unitintegration-tests) | Shallow — embedding model mocked |
| 27 | `test_rag_sparse_tokenize_returns_dict` | [test_services_rag.py](#teststest_services_ragpy-7--rag-engine-unitintegration-tests) | Yes |
| 28 | `test_rag_hybrid_search_returns_ranked_results` | [test_services_rag.py](#teststest_services_ragpy-7--rag-engine-unitintegration-tests) | Shallow — single pre-matched doc, fusion not really tested |
| 29 | `test_rag_reranker_orders_by_relevance` | [test_services_rag.py](#teststest_services_ragpy-7--rag-engine-unitintegration-tests) | **Stub** — `assert True`, ordering never checked |
| 30 | `test_rag_ingestion_with_fake_db` | [test_services_rag.py](#teststest_services_ragpy-7--rag-engine-unitintegration-tests) | Shallow — checks calls, not written data |
| 31 | `test_rag_asks_brain_returns_stream` | [test_services_rag.py](#teststest_services_ragpy-7--rag-engine-unitintegration-tests) | Yes |
| 32 | `test_get_secure_document_not_found_raises_404` | [test_services_vault.py](#teststest_services_vaultpy-5--secure-documentvault-path-handling) | Yes |
| 33 | `test_get_secure_document_no_file_path_raises_400` | [test_services_vault.py](#teststest_services_vaultpy-5--secure-documentvault-path-handling) | Yes |
| 34 | `test_get_secure_document_path_normalizes_prefix` | [test_services_vault.py](#teststest_services_vaultpy-5--secure-documentvault-path-handling) | Yes |
| 35 | `test_get_secure_document_missing_file_raises_404` | [test_services_vault.py](#teststest_services_vaultpy-5--secure-documentvault-path-handling) | Yes |
| 36 | `test_upload_to_brain_saves_file` | [test_services_vault.py](#teststest_services_vaultpy-5--secure-documentvault-path-handling) | Shallow — file I/O mocked |
| 37 | `test_models` | [test_structural_fixes.py](#teststest_structural_fixespy-2--modelsingleton-schema-smoke-tests) | Shallow — attribute-exists only |
| 38 | `test_rag_service` | [test_structural_fixes.py](#teststest_structural_fixespy-2--modelsingleton-schema-smoke-tests) | Shallow — attribute-exists only |
| 39 | `test_get_temporal_context_morning` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Yes |
| 40 | `test_get_temporal_context_night` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Yes |
| 41 | `test_get_temporal_context_sunday` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Yes |
| 42 | `test_analyze_emotional_tone_positive` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Yes |
| 43 | `test_analyze_emotional_tone_negative` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Yes |
| 44 | `test_analyze_emotional_tone_neutral` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Yes |
| 45 | `test_get_tone_guidance` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Yes |
| 46 | `test_find_associative_memories` | [test_subconscious_flow.py](#teststest_subconscious_flowpy-8--temporal-context--emotional-tone-heuristics) | Shallow — only checks non-empty, not relevance |
| 47 | `test_process_note_background_success` | [test_tasks.py](#teststest_taskspy-1--background-note-processing) | Yes |
| N1 | `test_ollama_stream_chunks_yields_text` | [test_services_ollama.py](#new-not-part-of-the-47--teststest_services_ollamapy-2-added-for-the-ollama-provider-track) | Yes |
| N2 | `test_ollama_generate_text_returns_content` | [test_services_ollama.py](#new-not-part-of-the-47--teststest_services_ollamapy-2-added-for-the-ollama-provider-track) | Yes |
| G1 | `test_grounding_score_high_when_answer_paraphrases_context` | [test_grounding_score.py](#follow-up-teststest_grounding_scorepy-4--eval-for-the-grounding-score-tripwire-itself) | Yes — real embedding model, no mocks |
| G2 | `test_grounding_score_low_when_answer_ignores_context` | [test_grounding_score.py](#follow-up-teststest_grounding_scorepy-4--eval-for-the-grounding-score-tripwire-itself) | Yes — real embedding model, no mocks |
| G3 | `test_grounding_score_empty_inputs_return_zero` | [test_grounding_score.py](#follow-up-teststest_grounding_scorepy-4--eval-for-the-grounding-score-tripwire-itself) | Yes |
| G4 | `test_async_grounding_score_matches_sync_result` | [test_grounding_score.py](#follow-up-teststest_grounding_scorepy-4--eval-for-the-grounding-score-tripwire-itself) | Yes |

Tally: **49/49 core suite PASS** (3 stubs that can't fail: #18, #24, #29; ~14 more "Shallow" — pass because the dependency under test is mocked to return exactly what's asserted) + **4/4 grounding-eval PASS**.

---

## `tests/test_api_e2e.py` (3) — live TestClient hitting a real signup/login/notes/files/RAG flow

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 1 | `test_notes_flow` | Signed-up/logged-in CI user; `POST /notes/` with `{"content": "This is a CI test note generated at <random>"}` | 201→200 on create; `GET /notes/` list contains a note with that exact content | 200 on create; note present in list |
| 2 | `test_files_flow` | Same user; `POST /chat/upload-to-brain` with a text file `ci_test_file_<random>.txt` / content `"CI test file content."` | 200 on upload; `GET /files/` vault list contains a file with that filename | 200; filename present in vault list |
| 3 | `test_rag_chat_flow` | Uploads brain content `"The airspeed velocity of an unladen swallow is 24mph."`, then `POST /chat/chat` with query `"What is the airspeed velocity of a swallow?"` | 200 status; SSE stream doesn't 500 (test deliberately does **not** assert the RAG answer is correct — only that the call flow completes) | 200; stream completed without crashing |

---

## `tests/test_api_routes.py` (11) — mocked-DB TestClient route tests

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 4 | `test_root_returns_200` | `GET /` | 200, `{"message": "Welcome to Brain Dump API"}` | 200, exact match |
| 5 | `test_signup_returns_200` | `POST /auth/signup` `{"email":"new@example.com","password":"Password123!","full_name":"New User"}`, mocked DB (no existing user) | 200, response `email == "new@example.com"` | 200, match |
| 6 | `test_login_returns_token` | `POST /auth/login` `{"email":"test@example.com","password":"password123"}`, mocked `verify_password→True`, `create_access_token→"fake_token"` | 200, `access_token == "fake_token"` | 200, match |
| 7 | `test_protected_route_without_token_returns_401` | `GET /chat/history` with no `Authorization` header | 401 | 401 |
| 8 | `test_notes_create_and_list` | `POST /notes/` `{"content":"Test note"}` (background processing mocked out), then `GET /notes/` | 200 on both; created note echoes `content == "Test note"`; list has length 1 with same content | 200/200, matched |
| 9 | `test_files_list_returns_200` | `GET /chat/files`, mocked DB returns `[]` | 200, `[]` | 200, `[]` |
| 10 | `test_analytics_consistency_returns_200` | `GET /analytics/consistency`, mocked DB returns `[]` | 200 | 200 |
| 11 | `test_nlp_parse_reminder_with_mock_gemini` | `POST /api/nlp/parse-reminder` `{"text":"Remind me to call Mom tomorrow at 10am","timezone":"UTC","current_time":"2025-03-19T10:00:00"}`, `gemini_service.generate_content` mocked to return `{"action":"Reminder","trigger_time":"2025-03-20T10:00:00","recurrence":{"frequency":"daily","interval":1}}` | 200, `action == "Reminder"` | 200, match |
| 12 | `test_nlp_parse_reminder_too_long_returns_400` | Same endpoint, `text` = 501 `"a"` characters | 400 | 400 |
| 13 | `test_health_context_endpoint_returns_200` | `POST /api/health/context` with a full HealthSnapshot-shaped payload (readiness, HR, HRV, sleep, steps, active energy) | 200 | 200 |
| 14 | `test_music_context_endpoint_returns_200` | `POST /api/music/context` with a `current_song`/`recent_songs` payload, `MusicAnalyzerService.analyze_tone` mocked to return `{"primary_tone":"Happy", ...}` | 200, `primary_tone == "Happy"` | 200, match |

---

## `tests/test_core_auth.py` (4) — JWT auth unit tests

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 15 | `test_valid_jwt_allows_access` | Freshly signed JWT `{"user_id":1}`, mocked DB returns a matching `User(id=1)` | `get_current_user` returns user with `id == 1` | matched |
| 16 | `test_expired_jwt_returns_401` | JWT signed with `expires_delta=-1min` (already expired) | Raises `HTTPException` with `status_code == 401` | raised, 401 |
| 17 | `test_tampered_jwt_returns_401` | Valid JWT with the last character of the signature flipped | Raises `HTTPException` with `status_code == 401` | raised, 401 |
| 18 | `test_missing_authorization_header_returns_401` | N/A — placeholder test (`assert True`); real coverage lives in `test_protected_route_without_token_returns_401` (row 7) | `True` | `True` (no real assertion of behavior here — worth noting as a documentation gap, not a bug) |

---

## `tests/test_core_database.py` (3) — Postgres/pgvector connectivity

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 19 | `test_database_connection` | `SELECT 1` via `SessionLocal()` | scalar result `== 1` | `1` |
| 20 | `test_pgvector_extension_exists` | `SELECT count(*) FROM pg_type WHERE typname = 'vector'` | count `> 0` | `> 0` (pgvector installed) |
| 21 | `test_engine_disposal` | N/A — smoke test | `engine is not None` | not None |

---

## `tests/test_services_gemini.py` (3) — Gemini streaming/error/NLP (now routed through the new `llm_service` factory, still resolving to the same `GeminiService` singleton by default)

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 22 | `test_gemini_chat_streaming` | `google.genai.Client` mocked; `generate_content_stream` returns 2 chunks `"Hello "`, `"world!"`; calls `ask_gemini_stream_async("context", "Hi", user_id=1)` | Yields exactly `["Hello ", "world!"]` | `["Hello ", "world!"]` |
| 23 | `test_gemini_error_handling` | Same mock, but `generate_content_stream.side_effect = Exception("API Quota Exceeded")` | Streaming raises an exception containing `"API Quota Exceeded"` | raised, message matched |
| 24 | `test_nlp_parsing_with_gemini` | Patches `GeminiService.generate_content` to return a JSON reminder string | `pass` — test body is a stub (`# Actual verification depends on implementation details`) | No real assertion executed; this test can't fail regardless of behavior — flagged as a coverage gap, not something this run validates |

---

## `tests/test_services_rag.py` (7) — RAG engine unit/integration tests

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 25 | `test_rag_ingestion_chunks_text` | 300-line repeated text, `index_text(filename, text, user_id, db)`, embeddings mocked to zeros | Returns `chunks_count > 1` | `> 1` |
| 26 | `test_rag_dense_embed_returns_vector` | `SentenceTransformer.encode` mocked to a 768-dim vector; `get_emb_fn().encode(["test message"])` | Vector length `768`, elements are `float` | `768`, `float` |
| 27 | `test_rag_sparse_tokenize_returns_dict` | `BM25Store()._tokenize("Hello World! This is a test.")` | `"hello"` and `"world"` present, punctuation `"!"` stripped | present/absent as expected |
| 28 | `test_rag_hybrid_search_returns_ranked_results` | Mocked dense (zeros) + BM25 (`get_scores→[0.5]`) + one fake `BrainEmbedding` doc "test result" / source `test.txt`; `retrieve_context(query, user_id, db)` | Returned `context` contains `"test result"`; `sources` contains `"test.txt"` | both present |
| 29 | `test_rag_reranker_orders_by_relevance` | `CrossEncoder.predict` mocked to `[0.9, 0.1]` | Placeholder assertion `assert True` — no actual re-rank-order check performed (test docstring claims it validates ordering, code doesn't) | `True` — flagged as a coverage gap: the re-ranker's actual ordering behavior isn't exercised |
| 30 | `test_rag_ingestion_with_fake_db` | `index_text("test.txt", "Some content", 1, db)`, mocked embeddings | `db.execute` and `db.commit` were called | both called |
| 31 | `test_rag_asks_brain_returns_stream` | `gemini_service.async_stream` (via `rag_engine`) mocked to yield `"chunk1"`, `"chunk2"`; `ask_gemini_stream_async("context", "query", 1)` | Yields `["chunk1", "chunk2"]` | `["chunk1", "chunk2"]` |

---

## `tests/test_services_vault.py` (5) — secure-document/vault path handling

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 32 | `test_get_secure_document_not_found_raises_404` | `get_secure_document(1, 999, db)`, DB returns no matching `StoredFile` | Raises `HTTPException(404)` | 404 |
| 33 | `test_get_secure_document_no_file_path_raises_400` | `StoredFile(file_path=None)` returned by DB | Raises `HTTPException(400)` | 400 |
| 34 | `test_get_secure_document_path_normalizes_prefix` | `StoredFile(file_path="backend/uploads/1_test.pdf")`, `os.path.exists→True` | Returned path has `backend/uploads` prefix stripped, starts with `uploads/` | stripped correctly |
| 35 | `test_get_secure_document_missing_file_raises_404` | `StoredFile(file_path="uploads/missing.pdf")`, `os.path.exists→False` | Raises `HTTPException(404)` | 404 |
| 36 | `test_upload_to_brain_saves_file` | `POST /chat/upload-to-brain` with `test.pdf` content, DB/user/background-task/`os.makedirs`/`open` all mocked | 200, `status == "processing"` | 200, `"processing"` |

---

## `tests/test_structural_fixes.py` (2) — model/singleton schema smoke tests

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 37 | `test_models` | `BrainEmbedding` model class | Has a `user_id` attribute | present |
| 38 | `test_rag_service` | Module-level `_rag_service` singleton | Not `None`; has a `bm25_store` attribute | not None, attribute present |

---

## `tests/test_subconscious_flow.py` (8) — temporal context / emotional tone heuristics

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 39 | `test_get_temporal_context_morning` | Mocked `datetime.now()` → Wed 2023-10-11 09:00 | Context string contains `"Morning thoughts hit different"` | present |
| 40 | `test_get_temporal_context_night` | Mocked `datetime.now()` → Wed 2023-10-11 23:00 | Contains `"Late night"` | present |
| 41 | `test_get_temporal_context_sunday` | Mocked `datetime.now()` → Sun 2023-10-15 14:00 | Contains `"Sunday. Planning mode"` | present |
| 42 | `test_analyze_emotional_tone_positive` | `"I am feeling great about this project! Optimization is working perfectly."` | `tone == "energized_optimistic"` | `"energized_optimistic"` |
| 43 | `test_analyze_emotional_tone_negative` | `"I am failing at this. Everything is broken and I'm stressed."` | `tone == "reflective_concerned"` | `"reflective_concerned"` |
| 44 | `test_analyze_emotional_tone_neutral` | `"The server is running on port 8000."` | `tone == "contemplative_neutral"` | `"contemplative_neutral"` |
| 45 | `test_get_tone_guidance` | `get_tone_guidance("reflective_concerned")`, `("energized_optimistic")`, `("unknown_state")` | Contains `"Be gentle"`; contains `"Match the energy"`; exactly `"Be authentic and direct."` | all three matched |
| 46 | `test_find_associative_memories` | Mocked embedding model + DB query chain returning 2 fake docs (`"Fitness is key"`, `"Running helps clear mind"`); query `"I want to improve my health"` | Returns a non-empty list of associations | non-empty list |

---

## `tests/test_tasks.py` (1) — background note processing

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| 47 | `test_process_note_background_success` | `process_note_background(1, "Test content", 1)`, DB/`rag_engine` mocked, DB returns a matching note | `rag_engine.index_text` called once; `db.commit` called | both called |

---

## New (not part of the 47) — `tests/test_services_ollama.py` (2), added for the Ollama provider track

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| N1 | `test_ollama_stream_chunks_yields_text` | `httpx.Client` mocked; NDJSON stream lines `{"message":{"content":"Hello "}}`, `{"message":{"content":"world!"}}`, `{"message":{"content":""},"done":true}`; `_stream_chunks("Hi", config)` with `system_instruction="be terse"` | Yields `["Hello ", "world!"]`; POST payload has `model=="qwen2.5:7b"`, messages `[{"role":"system","content":"be terse"},{"role":"user","content":"Hi"}]` | matched exactly |
| N2 | `test_ollama_generate_text_returns_content` | Mocked `httpx.Client.post` response `{"message":{"content":"{\"ok\": true}"}}`; `_generate_text("Give me JSON", config)` | Returns `'{"ok": true}'` | matched |

---

## Gaps noted while writing this up (not blocking, but worth knowing)

- **Row 18** (`test_missing_authorization_header_returns_401`) and **row 24** (`test_nlp_parsing_with_gemini`) and **row 29** (`test_rag_reranker_orders_by_relevance`) are placeholder/stub tests (`assert True` or `pass`) — they count toward the 47 passed but don't actually verify the behavior their names/docstrings claim to. They'll pass even if that behavior regresses.
- No test directly exercised the grounding-score feature itself as of the original 47-test run — closed below.

---

## Follow-up: `tests/test_grounding_score.py` (4) — eval for the grounding-score tripwire itself

The 47-test run above is a **non-regression** signal for the rest of the pipeline — it does not exercise `compute_grounding_score()` / `async_compute_grounding_score()` (`rag_engine.py`) or the new `grounding_score`/`grounded` SSE fields at all. Added this file specifically to close that gap, and deliberately used the **real** `BAAI/bge-base-en-v1.5` embedding model (already cached locally) instead of mocking it — the point of an eval here is to check the threshold actually separates grounded from ungrounded answers, not just that the function calls its dependencies correctly.

| # | Test | Input | Expected | Actual |
|---|------|-------|----------|--------|
| G1 | `test_grounding_score_high_when_answer_paraphrases_context` | Context: *"...went for a 5k run in the morning and felt energized afterwards, then had a smoothie..."*. Answer: a close paraphrase of the same content. | Score `>= GROUNDING_WARN_THRESHOLD (0.35)` | **0.9178** — well above threshold |
| G2 | `test_grounding_score_low_when_answer_ignores_context` | Same context. Answer: *"The capital of France is Paris, and the Eiffel Tower was completed in 1889..."* — topically unrelated, simulating the model answering from general knowledge instead of the retrieved note. | Score `< GROUNDING_WARN_THRESHOLD (0.35)` | **0.3363** — below threshold, correctly flagged |
| G3 | `test_grounding_score_empty_inputs_return_zero` | Empty answer, empty context, or both | `0.0` in all three cases | `0.0`, `0.0`, `0.0` |
| G4 | `test_async_grounding_score_matches_sync_result` | Same answer/context run through both `compute_grounding_score` (sync) and `async_compute_grounding_score` (executor-wrapped) | Scores equal within `1e-6` | matched |

**Result: 4/4 passed.** The threshold does its job on these two examples, but note the margin on G2 is thin — **0.3363 vs. a 0.35 cutoff, only ~0.014 apart**. That's a single adversarial-ish example, not a calibration study; the `GROUNDING_WARN_THRESHOLD` docstring already says 0.35 is "a conservative starting point... calibrate against real traffic," and this run doesn't change that recommendation — if anything it reinforces it. Worth running a larger batch of real grounded/ungrounded chat transcripts through this before trusting the threshold in prod alerting.
