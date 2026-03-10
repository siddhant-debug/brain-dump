---
description: BrainDumps Change Safety Workflows
---

# BrainDumps Change Safety Workflows

## CORE PRINCIPLE
Every change has a blast radius. Before touching anything, map what it affects.
Never start coding until the impact is understood.

---

## WORKFLOW 1: Before You Write a Single Line

Run this checklist before every task — no exceptions.

### 1. Identify the change type
- New feature (isolated) → low risk
- Editing an existing provider → high risk, touches every widget watching it
- Editing a shared model (copyWith, toJson, fromMap) → high risk, touches serialization everywhere
- Editing AppColors or AppTheme → very high risk, touches entire UI
- Editing a MethodChannel name or method string → critical risk, breaks native bridge silently
- Editing a base widget (_Card, PersistentHeader) → very high risk, renders everywhere

### 2. Find everything that depends on what you're changing
Before editing any file ask:
- Who imports this file? (search the codebase)
- Who watches this provider?
- Who calls this method?
- Who extends this class or implements this interface?

If the answer is "more than 2 places" — treat it as high risk.

### 3. Write down what must NOT break
State this explicitly before starting:
"I am changing X. The following must still work after:
- [list the features that touch X]"

---

## WORKFLOW 2: Editing an Existing Provider or Controller

These are the highest-risk changes because every widget watching
the provider will be affected.

### Before editing
- [ ] List every widget that calls ref.watch(thisProvider)
- [ ] List every widget that calls ref.read(thisProvider.notifier)
- [ ] Note every method on the notifier that outside code calls
- [ ] Note every field on the state that outside code reads

### Rules while editing
- Never rename a state field without updating every widget that reads it
- Never remove a copyWith parameter without checking all call sites
- Never change a method signature without updating all callers
- If adding a new required field to state — give it a default value
  so existing copyWith calls don't break

### After editing
- [ ] Search for every reference to changed fields/methods
- [ ] Check every widget that watches this provider still compiles
- [ ] Verify state transitions still work: unauthorized → authorized → fetching → data

---

## WORKFLOW 3: Editing a Shared Model

HealthSnapshot, MusicContextState, NowPlayingInfo etc.
These are serialized to JSON and sent to backend — changes break two things at once.

### Before editing
- [ ] Is this model serialized to JSON? (check toJson())
- [ ] Is this model deserialized from JSON? (check fromMap()/fromJson())
- [ ] Is this model sent to the backend? (check the controller's _postToBackend)
- [ ] Does the backend expect a specific schema? (check API constants)

### Rules while editing
- Adding a field → add to constructor, toJson(), fromMap(), copyWith() — all four
- Removing a field → check toJson() and fromMap() and remove there too
- Renaming a field → update the JSON key only if backend also changes — coordinate both
- Never change a JSON key name without updating the backend endpoint schema

### After editing
- [ ] toJson() contains every field
- [ ] fromMap() handles every field with a null fallback
- [ ] copyWith() includes every field
- [ ] Backend payload matches what controller sends

---

## WORKFLOW 4: Adding a New Screen or Page

New screens feel isolated but often break navigation and state.

### Before building
- [ ] Where does this screen navigate from?
- [ ] Does it need its own provider or share an existing one?
- [ ] Does it need auth gating?
- [ ] Does it affect the bottom nav or router?

### Rules while building
- Never create a new provider for data that already exists in another provider
- Never duplicate state — read from the existing provider instead
- If the screen opens as a bottom sheet — follow the exact existing pattern
- New screens must be wrapped in Scaffold only if they are full screens,
  not if they are bottom sheets

### After building
- [ ] Navigation to and from the screen works
- [ ] Back button / dismiss works correctly
- [ ] Provider is disposed when screen is popped (StateNotifierProvider auto-handles this)
- [ ] No duplicate providers created

---

## WORKFLOW 5: Editing the Swift MethodChannel Layer

Silent failures — Flutter sees null or gets no response with no error thrown.

### Before editing
- [ ] Note the exact channel name string — must match Dart exactly, character for character
- [ ] Note every method name string — must match Dart invokeMethod() calls exactly
- [ ] If removing a method — find every Dart call site first

### Rules while editing
- Never change a channel name without changing it in both Swift and Dart simultaneously
- Never rename a method string without updating the Dart invokeMethod() call
- Every new Swift method must be added to the switch in setupChannel()
- Every new HKObjectType must be added to readTypes AND will require re-auth prompt bump

### After editing
- [ ] Build succeeds in Xcode (zero warnings)
- [ ] Run on physical iPhone and check Xcode console for print output
- [ ] Every new method prints its result — confirms the channel is wired
- [ ] Flutter side receives non-null for at least one test case

---

## WORKFLOW 6: Editing the RAG System Prompt or Backend Context

Changes here affect AI response quality for all users — hardest to test.

### Before editing
- [ ] What context block are you changing? (health, music, notes)
- [ ] Does the backend endpoint schema need to change too?
- [ ] Does the Flutter payload toJson() need to match?

### Rules while editing
- Never remove a context field without confirming the LLM doesn't rely on it
- Always keep context human-readable — not raw JSON
- New context fields must have null-safe fallbacks in the prompt template
- Test the prompt with missing data (null health, no music) — must not break

### After editing
- [ ] Prompt works when all context fields are null
- [ ] Prompt works when only some context fields are populated
- [ ] Flutter toJson() matches the new backend schema
- [ ] Backend endpoint updated to handle new fields

---

## WORKFLOW 7: Dependency / Package Updates

pubspec.yaml changes break things in non-obvious ways.

### Rules
- Never update multiple packages at once
- After any pubspec change run: dart analyze before running the app
- After updating a package that wraps a native SDK (music_kit, health etc.)
  re-test the full native flow on physical iPhone — native APIs change between versions
- Never update Flutter SDK version mid-feature — finish the feature first

---

## WORKFLOW 8: The Pre-Commit Check

Run this before every commit — takes 2 minutes, saves hours.

### Code
- [ ] dart analyze → zero errors (warnings are okay, errors are not)
- [ ] Every new file has been imported where it's used
- [ ] No TODO left that blocks functionality (TODOs for future features are fine)
- [ ] No hardcoded strings that should be constants (API URLs, channel names, JWT keys)

### Native
- [ ] If Swift changed → Xcode build succeeds
- [ ] If HealthKit readTypes changed → version bump in init()
- [ ] If MethodChannel method added → case added to switch AND Dart invokeMethod added

### State
- [ ] Every new provider has dispose() implemented
- [ ] Every new AnimationController is disposed
- [ ] Every new Timer is cancelled in dispose()
- [ ] Every new WidgetsBindingObserver is removed in dispose()

### UI
- [ ] No hardcoded colors — AppColors only
- [ ] No hardcoded text styles — use existing text style patterns
- [ ] Every new bottom sheet follows the existing showModalBottomSheet pattern
- [ ] SYNCING/null states handled — nothing crashes on missing data

### RAG / Backend
- [ ] toJson() updated if model changed
- [ ] Backend payload matches updated model
- [ ] JWT key string matches 'jwt_token' exactly

---

## BLAST RADIUS QUICK REFERENCE

When you touch this → check these too:

| You change | Check these |
|---|---|
| AppColors | Every widget in the app |
| _Card widget | Every analytics card |
| HealthSnapshot model | health_service.dart, health_sync_controller.dart, health_dashboard_widget.dart, backend schema |
| MusicContextState | music_sync_controller.dart, music_vibe_bottom_sheet.dart, brain_insights_carousel.dart |
| MethodChannel name string | AppDelegate.swift + every Dart invokeMethod call |
| JWT storage key | Every controller that reads from secure storage |
| ApiConstants.baseUrl | Every http/dio call in every controller |
| PersistentHeader | Every screen |
| BrainInsightsCarousel | analytics_screen.dart |
| healthSyncControllerProvider | health_dashboard_widget.dart, brain_insights_carousel.dart, analytics_screen.dart |
| musicSyncControllerProvider | music_vibe_bottom_sheet.dart, brain_insights_carousel.dart, analytics_screen.dart |