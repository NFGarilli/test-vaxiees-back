# Technical Test: Room Reservation System

## Requirements

| | |
|---|---|
| **Duration** | 45 minutes maximum |
| **Recording** | **MANDATORY** - Record your entire session. We evaluate the process, not just the result. |
| **AI Usage** | **MANDATORY** - You must use AI (Claude Code, Copilot, etc.). Tests without AI usage will not be evaluated. |
| **Deliverable** | Git repository with all tests passing |

> **This test is designed to showcase your AI-assisted development skills. Impress us.**

---

## The Problem

**MeetingRooms Inc.** needs an API to manage meeting room reservations. The system must prevent booking conflicts.

---

## Business Rules

Each rule can be developed independently (git worktree compatible).

### BR1: No overlapping reservations
There cannot be more than one active reservation for the same room during the same time period.

### BR2: Maximum duration
A reservation cannot last more than 4 hours.

### BR3: Business hours only
Reservations can only be between 9:00 AM and 6:00 PM, Monday through Friday.

### BR4: Capacity restriction by user
A regular user (non-admin) can only book rooms whose capacity is ≤ their `max_capacity_allowed`. Administrators can book any room.

### BR5: Active reservation limit
A user cannot have more than 3 active reservations (future and not cancelled). Administrators have no limit.

### BR6: Advance cancellation
A reservation can only be cancelled if there are more than 60 minutes until its start time.

### BR7: Recurring reservations
When creating a reservation with `recurring = 'weekly'` or `'daily'`:
- All occurrences must be created until `recurring_until`
- ALL occurrences must comply with rules BR1-BR5
- If any occurrence violates a rule, NO reservations are created

---

## API Endpoints

### Rooms
```
GET    /api/v1/rooms
GET    /api/v1/rooms/:id
POST   /api/v1/rooms (admin only)
GET    /api/v1/rooms/:id/availability?date=YYYY-MM-DD
```

### Users
```
GET    /api/v1/users
POST   /api/v1/users
GET    /api/v1/users/:id
```

### Reservations
```
GET    /api/v1/reservations
POST   /api/v1/reservations
GET    /api/v1/reservations/:id
PATCH  /api/v1/reservations/:id/cancel
```

---

## Bonus Points
- Elegant API error handling
- Useful seeds for manual testing
- Edge cases we didn't mention

---

## Setup

```bash
bundle install
rails db:migrate
bundle exec rspec
rails server
```

Good luck!
