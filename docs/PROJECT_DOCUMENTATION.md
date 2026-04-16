# Coach Sessions — Project documentation (technical lead view)

This document describes **where the project stands today**, how it is built, what works, what is fragile, and how to move forward. It is written to be **clear for beginners** while staying accurate for developers.

---

## 1. The app today

### What it is

A **coach–client session booking** MVP: coaches see a week of time slots and pending booking requests; clients see open slots, request a session, and track their bookings.

The Flutter app can run in two modes:


| Mode               | How you turn it on                                          | What it uses                                                                                                |
| ------------------ | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Mock / offline** | `USE_BACKEND=false` in `assets/app.env` (or unset)          | Local fake users, schedule, and bookings — no server                                                        |
| **Live backend**   | `USE_BACKEND=true` + Firebase + API URL in `assets/app.env` | **Firebase Auth** (email/password) + **REST API** to your **Node/Express** server, which uses **Firestore** |


There is also an `**frontend/`** Expo app and a `**backend/**` Express API in this repo, aligned with the same Firebase project and API shapes.

### Features implemented

- **Login**
  - Mock: pick a name + role (coach vs client), no password.
  - Backend: Firebase email/password, then `GET /api/auth/me` for role and profile.
- **Coach**
  - Dashboard: list **pending** booking requests (approve / reject), simple **client roster** (mock “sessions remaining”).
  - Schedule: **week view** (Mon–Sun), **slots** per day; mock mode: **block / unblock** free slots, tap booked slot to see mock booking summary.
- **Client**
  - Home: see coach’s **open** slots for the week (read-only grid).
  - Book flow: pick day + slot, **request booking** (mock: pending + slot marked booked; backend: `POST /api/bookings/request`).
  - My bookings: lists **pending / confirmed / rejected** for the signed-in client.
- **Config**
  - `assets/app.env` (often synced from `frontend/.env`) for `USE_BACKEND`, `API_BASE_URL`, `DEFAULT_COACH_ID` (coach Firebase UID for client views).

### What works (when configured correctly)

- **End-to-end mock flow**: login → client books → coach sees pending → approve/reject → client sees updated status; coach can block/unblock slots in mock mode.
- **Backend flow** (with backend running, Firebase configured, Firestore `users/{uid}` with `role`, and env vars set): Firebase sign-in → load schedule + bookings from API → client can request booking with valid `apiSlotId` on slots → coach can approve/reject via API → refresh updates UI.
- **Navigation**: role-based home after login (`AppRoutes.replaceWithRoleHome`).
- **Refactored structure**: `ScheduleService` / `BookingService` own data rules; `AppState` wires auth + API + `notifyListeners`; feature screens use `ListenableBuilder` where needed so lists update.

### Partially implemented

- **Coach schedule editing with backend**: UI shows a message that changing hours needs `**PUT /api/schedule/weekly`**; block/unblock is **disabled** in backend mode (read-only schedule screen for coach edits).
- **“Real” multi-coach / multi-client**: mock uses a tiny fixed roster; backend uses real UIDs but client home needs `**DEFAULT_COACH_ID`** to know which coach’s public schedule to load.
- **Error handling / edge cases**: some failures surface as generic exceptions or snackbars; no rich retry/offline UX.
- **Tests**: a small smoke widget test only; no integration tests against a running API.

### Missing (not in the app yet)

- Push **notifications** when a booking is approved/rejected.
- **Password reset**, social login, email verification flows (Firebase can do them; UI not built).
- **Coach creating the week on-device** in backend mode (needs API + UI).
- **Payments**, packages, recurring sessions, calendars (Google/Outlook), admin roles.
- **Production hardening**: app check, rate limiting, analytics, crash reporting, CI/CD (may exist outside this doc).
- **Supabase**: the repo today uses **Express + Firestore + Firebase Auth**, not Supabase. A move to Supabase would be a **new backend + auth story** (see roadmap).

---

## 2. Architecture

### Repository layout (high level)

```
APP COUCH/
├── lib/                    # Flutter app (coach_sessions)
├── backend/                # Node + Express + Firebase Admin + Firestore
├── frontend/               # Expo + Firebase (shares env concepts with Flutter)
├── assets/app.env          # Flutter runtime env (often generated from frontend/.env)
├── scripts/                # e.g. sync_env_from_frontend.ps1
└── docs/                   # This documentation
```

### Flutter `lib/` folder structure


| Path                                 | Purpose                                                                                                                                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `**lib/main.dart**`                  | `WidgetsFlutterBinding`, `AppConfig.load()`, optional Firebase init, `appState.init()`, `MaterialApp` + routes                                                                             |
| `**lib/core/**`                      | **App-wide shell**: `app_state.dart` (session + notifier), `app_routes.dart` (named routes + helpers), `app_navigator.dart` (global navigator key), `config/app_config.dart` (env / flags) |
| `**lib/models/`**                    | Plain data: `User`, `Booking`, `TimeSlot`, enums (`UserRole`, `BookingStatus`, `SlotStatus`)                                                                                               |
| `**lib/services/schedule/**`         | `**ScheduleService**`: weekly slot map; mock block/unblock; applying API JSON. `**ScheduleCalendar**`: “this week’s Monday”, default slot template, date labels                            |
| `**lib/services/booking/**`          | `**BookingService**`: list of bookings; mock approve/reject; add pending request (coordinates with schedule)                                                                               |
| `**lib/services/api/**`              | `**CoachSessionsApi**` (HTTP), `**ScheduleApiMapper**` (JSON → slots)                                                                                                                      |
| `**lib/data/**`                      | `**MockSeed**`: demo users + initial week + one sample pending booking                                                                                                                     |
| `**lib/features/auth/**`             | Login screen                                                                                                                                                                               |
| `**lib/features/coach/**`            | Coach dashboard, coach schedule, coach slot bottom sheets                                                                                                                                  |
| `**lib/features/client/**`           | Client home, client booking                                                                                                                                                                |
| `**lib/features/booking/**`          | Client “My bookings” list                                                                                                                                                                  |
| `**lib/features/schedule/widgets/**` | `**WeekScheduleSection**`: reused day strip + slot grid block                                                                                                                              |
| `**lib/widgets/**`                   | Shared UI pieces: buttons, headers, `DayStrip`, `SlotGrid`                                                                                                                                 |
| `**lib/firebase_options.dart**`      | Firebase client configuration for Flutter                                                                                                                                                  |


### How data flows

1. **Startup**
  `main()` → `AppConfig.load()` reads `assets/app.env` → if `useBackend`, Firebase initializes → `appState.init()` either loads **mock seed** into `ScheduleService` + `BookingService` or clears them for **API fill after login**.
2. **After login**
  **Mock**: `AppState.login` sets `currentUser` from name/role.  
   **Backend**: Firebase sign-in → `CoachSessionsApi.authMe()` → `currentUser` from API + Firestore role → `refreshFromBackend()` loads schedule + bookings into services.
3. **UI reads state**
  Screens use the global `**appState`** (`ListenableBuilder` or `ListenableBuilder` in `main` wrapping `MaterialApp` plus local builders on some screens). Widgets call `**appState.slotsForDay**`, `**appState.bookings**`, `**appState.pendingRequests()**`, etc.
4. **UI writes state**
  Buttons call `**appState`** methods (`bookSessionAsync`, `approveBookingAsync`, `toggleBlockSlot`, …). `**AppState**` delegates to `**ScheduleService**` / `**BookingService**` and/or `**CoachSessionsApi**`, then `**notifyListeners()**`.

### How UI connects to services

There is **no** dependency-injection framework. A single global `**appState`** is the façade:

- UI → `**AppState**` only (good for a small MVP).
- `**AppState**` → `**ScheduleService**` + `**BookingService**` + `**CoachSessionsApi**` (when `useBackend`).

For a larger app, you would inject interfaces and test with fakes; here the split already makes it easier to swap mock vs API **inside** `AppState` and services.

---

## 3. Core systems

### Booking system

- **Mock**
  - Client picks an **available** slot → `**BookingService.addPendingRequestMock`** creates a `Booking` with status **pending** and `**ScheduleService.markSlotPendingBooking`** marks the slot **booked** and links `bookingId`.
  - Coach **approve**: status → **approved**; mock **client “sessions remaining”** in the directory may decrement.
  - Coach **reject**: status → **rejected**; `**ScheduleService.releaseSlot`** sets slot back to **available**.
- **Backend**
  - Client: `**POST /api/bookings/request`** with coach id, week start, date, slot id (from API slot’s `apiSlotId`).
  - Coach: `**PATCH /api/bookings/:id/decision**` approve/reject.
  - Then `**refreshFromBackend()**` reloads schedule + booking lists from the API and updates the same in-memory models.

### Schedule system

- **Slot generation (mock)**  
`**ScheduleCalendar.defaultSlotsForDay()`** builds **7 hourly slots** (roughly 4pm–10pm) with US-style time labels. `**MockSeed`** copies that template for each weekday and tweaks a few cells (blocked / booked sample).
- **Slot generation (API)**  
`**ScheduleApiMapper.mapCoachWeek`** / `**mapPublicWeek**` reads the JSON from your backend and fills `**TimeSlot**` (time label, status, `bookingId`, `apiSlotId`). Public view **filters** to available-only slots.
- **Updates**  
Mock: `**ScheduleService.toggleBlockSlot`**, booking mock methods mutate the same lists. Backend: replace the whole week from API after each successful refresh.

### Approval system

- **Mock**: `**BookingService.approveMock` / `rejectMock`** (+ schedule release on reject). `**AppState**` handles extra mock-only directory updates on approve.
- **Backend**: `**CoachSessionsApi.decideBooking`**, then full `**refreshFromBackend()**` so UI matches server.

### Role-based navigation

- `**UserRole**`: `coach` | `client`.
- `**AppRoutes.replaceWithRoleHome**`: after login, `**Navigator.pushReplacementNamed**` to `**/coach/dashboard**` or `**/client/home**`.
- Route names are centralized in `**lib/core/app_routes.dart**` so paths are not scattered as string literals everywhere.

---

## 4. Current limitations

### Scalability / design

- **Global `appState`**: simple, but every test/widget must remember to init config/state; harder to run multiple isolated apps in one process.
- **In-memory schedule + bookings**: no local DB cache; every cold start refetches or reseeds mock.
- **Single “current coach” for clients** in backend mode via `**DEFAULT_COACH_ID`** — not a marketplace model yet.

### What already needs a backend

- Anything labeled **backend mode** (`USE_BACKEND=true`): auth, schedule, bookings **require** the Express server + Firebase Admin + Firestore rules/data you set up.

### What can break in real-world usage

- **Wrong `API_BASE_URL`** (emulator vs desktop vs physical device): easy to get 404 or connection errors; the app tries to rewrite `10.0.2.2` on non-Android, but physical devices still need the **PC’s LAN IP**.
- **Missing Firestore `users/{uid}.role`**: API returns **403** “role not found” after Firebase sign-in.
- **Cleartext HTTP** on Android: may need manifest / network security config for production (debug often OK).
- **No optimistic UI** for slow networks: user may tap twice or think nothing happened.
- **Coach cannot edit weekly hours in Flutter** when backend is on — must use API/other tool until UI is built.

---

## 5. Roadmap (suggested)

> **Note:** Your codebase today uses **Firebase Auth + Express + Firestore**. If Phase 2 targets **Supabase**, plan for **auth replacement**, **new database schema**, and **rewriting or proxying** the current REST API. The phases below keep that explicit.

### PHASE 1 — Stabilize (short term)

- Run through **mock** and **backend** flows on **Android emulator**, **Windows/desktop**, and (if available) **physical device**; fix any env or URL issues.
- Add **loading indicators** on login, book, approve/reject, and refresh.
- Unify **error messages** (network vs 403 vs 404) for non-developers.
- **Coach schedule + backend**: either document “edit via API only” or implement minimal **PUT /api/schedule/weekly** UI.
- Expand **widget/integration tests** for critical paths (optional but high value).

### PHASE 2 — Backend & data (medium term)

**Pick one track (or sequence):**

- **Track A — Deepen current stack**  
Harden Express routes, Firestore indexes/security rules, idempotency for bookings, pagination, and align Flutter + Expo behavior.
- **Track B — Migrate to Supabase (your stated goal)**  
Design Postgres tables (`profiles`, `coaches`, `availability_slots`, `bookings`, …), **Supabase Auth**, Row Level Security policies, and replace `**CoachSessionsApi`** with Supabase client calls (or a thin Edge Functions layer). Retire or parallel-run Express during migration.

Deliverables either way: **single source of truth** for schedule + bookings, **no mock in production**, and clear **environment** separation (dev/staging/prod).

### PHASE 3 — Notifications & auth quality

- **Push notifications** (FCM or Supabase channels) for approve/reject and new requests.
- **Email verification**, **password reset**, optional **OAuth** providers.
- **Roles/claims** aligned between auth provider and database (no “signed in but no role” dead ends).

### PHASE 4 — UX & advanced product

- Onboarding, empty states, skeleton loaders, accessibility pass.
- Multi-coach discovery, favorites, packages/credits, calendar sync.
- Analytics, admin dashboards, abuse prevention.

---

## 6. Simple explanation (non-technical)

Imagine a **personal trainer’s calendar** on your phone.

- The **coach** opens the app and sees the week like a planner. Some hours are free, some are blocked, and sometimes a **client asked for a session** — that shows up as a **request**. The coach taps **yes** or **no**.
- The **client** opens the app and sees **only the hours they’re allowed to book**. They pick a time and send a **request**. It is not final until the coach says yes.
- There is a **“My bookings”** page so the client can see what’s waiting, what’s confirmed, and what was declined.

Right now the app can run like a **demo with pretend people** on your phone, or it can talk to a **real server** in your project folder so the same actions hit a **real database** — but setting that up requires a few technical switches (sign-in, internet address of the server, and who is the coach).

---

## 7. Copy-paste prompt for ChatGPT

Use the block below as **one message** to another assistant. Fill the bracketed parts if you want.

```
You are helping me on a Flutter MVP called “Coach Sessions” (coach–client booking).

## Product
- Coaches manage a weekly schedule and approve/reject booking requests.
- Clients see open slots, request bookings, and view their booking history.
- Two run modes: MOCK (local fake data) and BACKEND (Firebase Auth + REST API to Node/Express + Firestore). Toggle via assets/app.env USE_BACKEND and API_BASE_URL / DEFAULT_COACH_ID.

## Repo layout (important paths)
- Flutter: lib/ — main.dart, core/ (app_state, app_routes, config), models/, services/schedule/, services/booking/, services/api/, data/mock_seed.dart, features/{auth,coach,client,booking,schedule/widgets}, widgets/
- Backend: backend/ Express app (port 4000 typical), Firestore + Firebase Admin
- Expo: frontend/ shares env keys; scripts/sync_env_from_frontend.ps1 can refresh assets/app.env

## Current progress
- Mock flow works end-to-end (book → pending → approve/reject → UI updates).
- Backend path works when server + Firebase + Firestore user roles are configured; coach schedule screen is read-only for edits in backend mode (PUT /api/schedule/weekly not exposed in Flutter yet).
- Refactor done: ScheduleService + BookingService own rules; AppState coordinates API + notifyListeners; AppRoutes centralizes navigation.

## What I want from you
1. [DESCRIBE YOUR GOAL — e.g. “implement coach weekly editor against existing API” OR “plan migration to Supabase” OR “fix X bug”]
2. Read paths I mention and suggest concrete file-level changes.
3. Keep answers beginner-friendly but technically precise.
4. If you propose new dependencies or a big restructure, say why and the tradeoffs.

## Constraints
- Prefer small, reviewable diffs; don’t rewrite unrelated modules.
- Note: production today is Firebase+Express+Firestore, not Supabase, unless I say we’re migrating.

When unsure, ask me for: USE_BACKEND value, target device (emulator vs Windows vs phone), and the exact error text or screenshot description.
```

---

## Document maintenance

- When you add a major feature, update **Section 1** (what exists) and **Section 5** (roadmap checkboxes).
- When you change folders or auth stack, update **Section 2** and the **ChatGPT prompt** so assistants stay aligned.

*Last aligned with codebase layout: Flutter `lib/` refactor with `core/`, `services/`, `features/`.*