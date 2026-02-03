# Room Reservations - Technical Test

## Project Context

This is a meeting room reservation system. Your task is to implement the business rules and REST API following TDD.

## Tech Stack

- **Rails 8** (API mode)
- **SQLite** (already configured, no additional setup)
- **RSpec** for testing
- **FactoryBot** for fixtures
- **Shoulda Matchers** for validations

## Useful Commands

```bash
# Run tests
bundle exec rspec

# Run a specific test
bundle exec rspec spec/models/reservation_spec.rb

# Run tests with detailed output
bundle exec rspec --format documentation

# Start server
rails server

# Rails console
rails console
```

## Existing Models

Models are already created with their migrations:

### Room
- `name` (string) - Unique room name
- `capacity` (integer) - Maximum capacity
- `has_projector` (boolean)
- `has_video_conference` (boolean)
- `floor` (integer)

### User
- `name` (string)
- `email` (string) - Unique
- `department` (string)
- `max_capacity_allowed` (integer) - Maximum room capacity they can book
- `is_admin` (boolean) - Default false

### Reservation
- `room_id` (references)
- `user_id` (references)
- `title` (string)
- `starts_at` (datetime)
- `ends_at` (datetime)
- `recurring` (string) - null, 'daily', 'weekly'
- `recurring_until` (date)
- `cancelled_at` (datetime) - null if active

## Business Rules to Implement

### BR1: No overlapping reservations
There cannot be two active reservations for the same room at the same time.

### BR2: Maximum duration of 4 hours
A reservation cannot last more than 4 hours.

### BR3: Business hours only
Reservations must be between 9:00 AM and 6:00 PM, Monday through Friday.

### BR4: Capacity restriction
Regular users can only book rooms with capacity ≤ their `max_capacity_allowed`. Admins can book any room.

### BR5: Maximum 3 active reservations
A regular user cannot have more than 3 active reservations (future, not cancelled). Admins have no limit.

### BR6: Advance cancellation
A reservation can only be cancelled if there are more than 60 minutes until start time.

### BR7: Recurring reservations
When creating recurring reservations, all occurrences must comply with the rules. If any fails, none are created.

## TDD Workflow

1. **Write the test first** - Describe the expected behavior
2. **Verify it fails** - `bundle exec rspec` should show red
3. **Implement minimum code** - Only what's needed to pass the test
4. **Verify it passes** - `bundle exec rspec` should show green
5. **Refactor if needed** - Keep tests green
6. **Commit** - One commit per red-green-refactor cycle

## Test Example

```ruby
# spec/models/reservation_spec.rb
RSpec.describe Reservation, type: :model do
  describe 'BR2: Maximum duration' do
    it 'does not allow reservations longer than 4 hours' do
      reservation = build(:reservation,
        starts_at: Time.zone.parse('2024-01-15 10:00'),
        ends_at: Time.zone.parse('2024-01-15 15:00') # 5 hours
      )

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include('Reservation cannot last more than 4 hours')
    end
  end
end
```

## Tips for Using Claude Code

- Ask it to generate tests first, then implementation
- Be specific about the error messages you want
- Ask it to cover edge cases
- Review generated code before committing
- If something doesn't work, describe the error and ask for correction

## API Endpoints (to implement)

```
GET    /api/v1/rooms
GET    /api/v1/rooms/:id
POST   /api/v1/rooms (admin only)
GET    /api/v1/rooms/:id/availability?date=YYYY-MM-DD

GET    /api/v1/users
POST   /api/v1/users
GET    /api/v1/users/:id

GET    /api/v1/reservations
POST   /api/v1/reservations
GET    /api/v1/reservations/:id
PATCH  /api/v1/reservations/:id/cancel
```

## Expected Commit Structure

```
test(room): add validation tests for Room model
feat(room): implement Room validations
test(user): add validation tests for User model
feat(user): implement User validations
test(reservation): add BR1 overlapping tests
feat(reservation): implement no-overlap validation
...
```
