# Room Reservations API

Meeting room reservation management system.

## Requirements

- Ruby 3.2+
- Bundler

## Setup

```bash
# Install dependencies
bundle install

# Create database
rails db:migrate

# Verify it works
bundle exec rspec
```

## Useful Commands

```bash
# Run tests
bundle exec rspec

# Run tests with details
bundle exec rspec --format documentation

# Start server
rails server

# Interactive console
rails console
```

## Project Structure

```
app/
  models/
    room.rb           # Room model
    user.rb           # User model
    reservation.rb    # Reservation model
  controllers/
    api/v1/           # API controllers (to implement)
spec/
  models/             # Model tests
  factories/          # Test factories
  requests/           # API tests (to implement)
```

## Documentation

See `CLAUDE.md` for detailed instructions on the business rules to implement.
