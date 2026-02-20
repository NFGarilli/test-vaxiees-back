puts "Seeding database..."

# Users
admin = User.find_or_create_by!(email: "admin@meetingrooms.com") do |u|
  u.name = "Alice Admin"
  u.department = "Management"
  u.max_capacity_allowed = 50
  u.is_admin = true
end

regular = User.find_or_create_by!(email: "bob@meetingrooms.com") do |u|
  u.name = "Bob Developer"
  u.department = "Engineering"
  u.max_capacity_allowed = 10
  u.is_admin = false
end

limited = User.find_or_create_by!(email: "carol@meetingrooms.com") do |u|
  u.name = "Carol Intern"
  u.department = "Engineering"
  u.max_capacity_allowed = 4
  u.is_admin = false
end

puts "  Created #{User.count} users"

# Rooms
small = Room.find_or_create_by!(name: "Focus Room") do |r|
  r.capacity = 4
  r.has_projector = false
  r.has_video_conference = false
  r.floor = 1
end

medium = Room.find_or_create_by!(name: "Collaboration Hub") do |r|
  r.capacity = 10
  r.has_projector = true
  r.has_video_conference = false
  r.floor = 2
end

large = Room.find_or_create_by!(name: "Board Room") do |r|
  r.capacity = 20
  r.has_projector = true
  r.has_video_conference = true
  r.floor = 3
end

puts "  Created #{Room.count} rooms"

# Reservations (only if none exist)
if Reservation.count.zero?
  monday = Time.zone.now.next_occurring(:monday)

  Reservation.create!(
    room: medium, user: regular, title: "Sprint Planning",
    starts_at: monday.change(hour: 10),
    ends_at: monday.change(hour: 12)
  )

  Reservation.create!(
    room: small, user: regular, title: "1:1 with Manager",
    starts_at: monday.change(hour: 14),
    ends_at: monday.change(hour: 15)
  )

  Reservation.create!(
    room: large, user: admin, title: "All Hands",
    starts_at: monday.change(hour: 16),
    ends_at: monday.change(hour: 18)
  )

  tuesday = monday + 1.day
  Reservation.create!(
    room: small, user: limited, title: "Onboarding Session",
    starts_at: tuesday.change(hour: 9),
    ends_at: tuesday.change(hour: 11)
  )

  puts "  Created #{Reservation.count} reservations"
else
  puts "  Reservations already exist, skipping"
end

puts "Seeding complete!"
