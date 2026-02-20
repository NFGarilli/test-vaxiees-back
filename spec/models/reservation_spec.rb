require 'rails_helper'

RSpec.describe Reservation, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:room) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_presence_of(:ends_at) }

    it 'rejects ends_at before starts_at' do
      reservation = build(:reservation,
        starts_at: Time.zone.now.next_occurring(:monday).change(hour: 12),
        ends_at: Time.zone.now.next_occurring(:monday).change(hour: 10))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:ends_at]).to include("must be after starts_at")
    end

    it 'rejects ends_at equal to starts_at' do
      time = Time.zone.now.next_occurring(:monday).change(hour: 10)
      reservation = build(:reservation, starts_at: time, ends_at: time)

      expect(reservation).not_to be_valid
      expect(reservation.errors[:ends_at]).to include("must be after starts_at")
    end
  end

  describe 'multiple validation errors' do
    it 'accumulates errors from multiple violated rules' do
      saturday = Time.zone.now.next_occurring(:saturday)
      reservation = build(:reservation,
        starts_at: saturday.change(hour: 8),
        ends_at: saturday.change(hour: 14)) # weekend + before 9 + 6 hours > 4

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base].size).to be >= 2
    end
  end

  describe 'BR1: No overlapping reservations' do
    let(:room) { create(:room) }
    let(:user) { create(:user) }
    let(:monday) { Time.zone.now.next_occurring(:monday) }

    let!(:existing_reservation) do
      create(:reservation, room: room, user: user,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 12))
    end

    context 'when new reservation overlaps with existing one in the same room' do
      it 'rejects a reservation that starts during an existing one' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 11),
          ends_at: monday.change(hour: 13))

        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include(a_string_matching(/overlap/i))
      end

      it 'rejects a reservation that ends during an existing one' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 9),
          ends_at: monday.change(hour: 11))

        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include(a_string_matching(/overlap/i))
      end

      it 'rejects a reservation that contains an existing one entirely' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 9),
          ends_at: monday.change(hour: 13))

        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include(a_string_matching(/overlap/i))
      end

      it 'rejects a reservation contained within an existing one' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 10, min: 15),
          ends_at: monday.change(hour: 11, min: 45))

        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include(a_string_matching(/overlap/i))
      end

      it 'rejects a reservation with exact same time slot' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 12))

        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include(a_string_matching(/overlap/i))
      end
    end

    context 'when reservations do not overlap' do
      it 'allows a reservation immediately after the existing one (adjacent)' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 12),
          ends_at: monday.change(hour: 13))

        expect(reservation).to be_valid
      end

      it 'allows a reservation immediately before the existing one (adjacent)' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 9),
          ends_at: monday.change(hour: 10))

        expect(reservation).to be_valid
      end

      it 'allows a reservation at a completely different time' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 14),
          ends_at: monday.change(hour: 15))

        expect(reservation).to be_valid
      end
    end

    context 'when reservation is in a different room' do
      it 'allows overlapping times in different rooms' do
        other_room = create(:room)
        reservation = build(:reservation, room: other_room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 12))

        expect(reservation).to be_valid
      end
    end

    context 'when existing reservation is cancelled' do
      it 'allows overlapping with a cancelled reservation' do
        existing_reservation.update!(cancelled_at: Time.zone.now)

        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 12))

        expect(reservation).to be_valid
      end
    end

    context 'when overlap is just 1 minute' do
      it 'rejects even a 1-minute overlap' do
        reservation = build(:reservation, room: room,
          starts_at: monday.change(hour: 11, min: 59),
          ends_at: monday.change(hour: 13))

        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include(a_string_matching(/overlap/i))
      end
    end

    context 'when updating an existing reservation' do
      it 'does not conflict with itself' do
        expect(existing_reservation).to be_valid
        existing_reservation.title = 'Updated title'
        expect(existing_reservation).to be_valid
      end
    end
  end

  describe 'BR2: Maximum duration of 4 hours' do
    let(:monday) { Time.zone.now.next_occurring(:monday) }

    it 'allows a reservation of exactly 4 hours' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 14))

      expect(reservation).to be_valid
    end

    it 'allows a reservation shorter than 4 hours' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      expect(reservation).to be_valid
    end

    it 'rejects a reservation longer than 4 hours' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 15))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/4 hours/i))
    end

    it 'rejects a reservation of exactly 4 hours and 1 minute' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 14, min: 1))

      expect(reservation).not_to be_valid
    end
  end

  describe 'BR3: Business hours only (9-18, Mon-Fri)' do
    let(:monday) { Time.zone.now.next_occurring(:monday) }
    let(:saturday) { Time.zone.now.next_occurring(:saturday) }
    let(:sunday) { Time.zone.now.next_occurring(:sunday) }

    it 'allows a reservation within business hours on a weekday' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 9),
        ends_at: monday.change(hour: 10))

      expect(reservation).to be_valid
    end

    it 'allows a reservation ending exactly at 18:00' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 17),
        ends_at: monday.change(hour: 18))

      expect(reservation).to be_valid
    end

    it 'rejects a reservation starting before 9:00' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 8),
        ends_at: monday.change(hour: 10))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/business hours/i))
    end

    it 'rejects a reservation ending after 18:00' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 17),
        ends_at: monday.change(hour: 19))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/business hours/i))
    end

    it 'rejects a reservation on Saturday' do
      reservation = build(:reservation,
        starts_at: saturday.change(hour: 10),
        ends_at: saturday.change(hour: 11))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/business hours/i))
    end

    it 'rejects a reservation on Sunday' do
      reservation = build(:reservation,
        starts_at: sunday.change(hour: 10),
        ends_at: sunday.change(hour: 11))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/business hours/i))
    end

    it 'rejects a reservation starting at exactly 18:00' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 18),
        ends_at: monday.change(hour: 19))

      expect(reservation).not_to be_valid
    end

    it 'rejects a reservation starting at 8:59' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 8, min: 59),
        ends_at: monday.change(hour: 10))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/business hours/i))
    end

    it 'rejects a reservation ending at 18:01' do
      reservation = build(:reservation,
        starts_at: monday.change(hour: 17),
        ends_at: monday.change(hour: 18, min: 1))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/business hours/i))
    end

    it 'allows a reservation on Friday within business hours' do
      friday = Time.zone.now.next_occurring(:friday)
      reservation = build(:reservation,
        starts_at: friday.change(hour: 9),
        ends_at: friday.change(hour: 10))

      expect(reservation).to be_valid
    end
  end

  describe 'BR4: Capacity restriction by user' do
    let(:monday) { Time.zone.now.next_occurring(:monday) }
    let(:large_room) { create(:room, capacity: 20) }
    let(:small_room) { create(:room, capacity: 5) }

    context 'when user is not admin' do
      let(:user) { create(:user, max_capacity_allowed: 10) }

      it 'allows booking a room within capacity limit' do
        reservation = build(:reservation, user: user, room: small_room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 11))

        expect(reservation).to be_valid
      end

      it 'allows booking a room at exact capacity limit' do
        room = create(:room, capacity: 10)
        reservation = build(:reservation, user: user, room: room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 11))

        expect(reservation).to be_valid
      end

      it 'rejects booking a room exceeding capacity limit' do
        reservation = build(:reservation, user: user, room: large_room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 11))

        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include(a_string_matching(/capacity/i))
      end
    end

    context 'when user is admin' do
      let(:admin) { create(:user, :admin, max_capacity_allowed: 5) }

      it 'allows booking any room regardless of capacity' do
        reservation = build(:reservation, user: admin, room: large_room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 11))

        expect(reservation).to be_valid
      end
    end
  end

  describe 'BR5: Active reservation limit (max 3 per user)' do
    let(:user) { create(:user) }
    let(:monday) { Time.zone.now.next_occurring(:monday) }

    before do
      3.times do |i|
        create(:reservation, user: user,
          starts_at: monday.change(hour: 10 + i),
          ends_at: monday.change(hour: 11 + i))
      end
    end

    it 'rejects a 4th active reservation for a regular user' do
      reservation = build(:reservation, user: user,
        starts_at: monday.change(hour: 14),
        ends_at: monday.change(hour: 15))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/3 active/i))
    end

    it 'allows a new reservation if one existing is cancelled' do
      user.reservations.first.update!(cancelled_at: Time.zone.now)

      reservation = build(:reservation, user: user,
        starts_at: monday.change(hour: 14),
        ends_at: monday.change(hour: 15))

      expect(reservation).to be_valid
    end

    it 'does not count past reservations toward the limit' do
      past_monday = 2.weeks.ago.beginning_of_week(:monday)
      user.reservations.update_all(
        starts_at: past_monday.change(hour: 10),
        ends_at: past_monday.change(hour: 11)
      )

      reservation = build(:reservation, user: user,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      expect(reservation).to be_valid
    end

    it 'allows exactly 3 active reservations' do
      user_with_two = create(:user)
      2.times do |i|
        create(:reservation, user: user_with_two,
          starts_at: monday.change(hour: 10 + i),
          ends_at: monday.change(hour: 11 + i))
      end

      reservation = build(:reservation, user: user_with_two,
        starts_at: monday.change(hour: 14),
        ends_at: monday.change(hour: 15))

      expect(reservation).to be_valid
    end

    it 'counts reservations across different rooms' do
      reservation = build(:reservation, user: user, room: create(:room),
        starts_at: monday.change(hour: 14),
        ends_at: monday.change(hour: 15))

      expect(reservation).not_to be_valid
      expect(reservation.errors[:base]).to include(a_string_matching(/3 active/i))
    end

    context 'when user is admin' do
      let(:admin) { create(:user, :admin) }

      it 'allows unlimited active reservations' do
        4.times do |i|
          create(:reservation, user: admin,
            starts_at: monday.change(hour: 10 + i),
            ends_at: monday.change(hour: 11 + i))
        end

        reservation = build(:reservation, user: admin,
          starts_at: monday.change(hour: 15),
          ends_at: monday.change(hour: 16))

        expect(reservation).to be_valid
      end
    end
  end

  describe 'BR6: Advance cancellation (>60 minutes before start)' do
    let(:monday) { Time.zone.now.next_occurring(:monday) }

    let!(:reservation) do
      create(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))
    end

    it 'allows cancellation more than 60 minutes before start' do
      travel_to monday.change(hour: 8, min: 59) do
        expect(reservation.cancel).to be true
        expect(reservation.reload.cancelled_at).not_to be_nil
      end
    end

    it 'allows cancellation exactly 61 minutes before start' do
      travel_to monday.change(hour: 8, min: 59) do
        expect(reservation.cancel).to be true
      end
    end

    it 'rejects cancellation exactly 60 minutes before start' do
      travel_to monday.change(hour: 9, min: 0) do
        expect(reservation.cancel).to be false
        expect(reservation.errors[:base]).to include(a_string_matching(/60 minutes/i))
      end
    end

    it 'rejects cancellation less than 60 minutes before start' do
      travel_to monday.change(hour: 9, min: 30) do
        expect(reservation.cancel).to be false
        expect(reservation.reload.cancelled_at).to be_nil
      end
    end

    it 'rejects cancellation after the reservation has started' do
      travel_to monday.change(hour: 10, min: 30) do
        expect(reservation.cancel).to be false
      end
    end

    it 'rejects cancellation of an already cancelled reservation' do
      travel_to monday.change(hour: 8) do
        reservation.cancel
        expect(reservation.cancel).to be false
        expect(reservation.errors[:base]).to include(a_string_matching(/already cancelled/i))
      end
    end
  end

  describe 'BR7: Recurring reservations' do
    let(:room) { create(:room) }
    let(:user) { create(:user, :admin) }
    let(:monday) { Time.zone.now.next_occurring(:monday) }

    describe '.create_recurring' do
      context 'with weekly recurrence' do
        it 'creates reservations for each week until recurring_until' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Standup",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: (monday + 3.weeks).to_date
          }

          result = Reservation.create_recurring(attrs)

          expect(result[:success]).to be true
          expect(result[:reservations].size).to eq(4)
          result[:reservations].each do |r|
            expect(r).to be_persisted
            expect(r.starts_at.wday).to eq(1) # Monday
          end
        end
      end

      context 'with daily recurrence' do
        it 'creates reservations for each weekday until recurring_until' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Daily sync",
            starts_at: monday.change(hour: 9),
            ends_at: monday.change(hour: 10),
            recurring: "daily",
            recurring_until: (monday + 4.days).to_date # Mon-Fri
          }

          result = Reservation.create_recurring(attrs)

          expect(result[:success]).to be true
          expect(result[:reservations]).to all(be_persisted)
          result[:reservations].each do |r|
            expect(r.starts_at).to be_on_weekday
          end
        end

        it 'skips weekends for daily recurrence' do
          # Start on Friday, recurring_until next Tuesday
          friday = Time.zone.now.next_occurring(:friday)
          attrs = {
            room_id: room.id, user_id: user.id, title: "Daily sync",
            starts_at: friday.change(hour: 10),
            ends_at: friday.change(hour: 11),
            recurring: "daily",
            recurring_until: (friday + 4.days).to_date # Fri -> next Tue
          }

          result = Reservation.create_recurring(attrs)

          expect(result[:success]).to be true
          days = result[:reservations].map { |r| r.starts_at.wday }
          expect(days).not_to include(0, 6) # No Sunday(0) or Saturday(6)
        end
      end

      context 'all-or-nothing behavior' do
        it 'creates no reservations if any occurrence overlaps (BR1)' do
          # Create an existing reservation on the 2nd week
          second_monday = monday + 1.week
          create(:reservation, room: room,
            starts_at: second_monday.change(hour: 10),
            ends_at: second_monday.change(hour: 11))

          attrs = {
            room_id: room.id, user_id: user.id, title: "Weekly",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: (monday + 3.weeks).to_date
          }

          expect { Reservation.create_recurring(attrs) }
            .not_to change(Reservation, :count)

          result = Reservation.create_recurring(attrs)
          expect(result[:success]).to be false
          expect(result[:errors]).to be_present
        end

        it 'creates no reservations if any occurrence violates BR2 (duration)' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Long meeting",
            starts_at: monday.change(hour: 9),
            ends_at: monday.change(hour: 14), # 5 hours
            recurring: "weekly",
            recurring_until: (monday + 1.week).to_date
          }

          expect { Reservation.create_recurring(attrs) }
            .not_to change(Reservation, :count)
        end

        it 'creates no reservations if any occurrence violates BR3 (business hours)' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Late meeting",
            starts_at: monday.change(hour: 17),
            ends_at: monday.change(hour: 19), # ends after 18:00
            recurring: "weekly",
            recurring_until: (monday + 1.week).to_date
          }

          expect { Reservation.create_recurring(attrs) }
            .not_to change(Reservation, :count)
        end

        it 'creates no reservations if total exceeds BR5 active limit' do
          regular_user = create(:user)
          attrs = {
            room_id: room.id, user_id: regular_user.id, title: "Recurring",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: (monday + 3.weeks).to_date # 4 occurrences > 3 limit
          }

          expect { Reservation.create_recurring(attrs) }
            .not_to change(Reservation, :count)
        end

        it 'creates no reservations if room capacity exceeds user limit (BR4)' do
          limited_user = create(:user, :limited, max_capacity_allowed: 5)
          big_room = create(:room, :large, capacity: 20)

          attrs = {
            room_id: big_room.id, user_id: limited_user.id, title: "Weekly",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: (monday + 1.week).to_date
          }

          expect { Reservation.create_recurring(attrs) }
            .not_to change(Reservation, :count)
        end

        it 'rejects when existing reservations plus occurrences exceed BR5 limit' do
          regular_user = create(:user)
          # Create 2 existing reservations
          2.times do |i|
            create(:reservation, user: regular_user,
              starts_at: monday.change(hour: 14 + i),
              ends_at: monday.change(hour: 15 + i))
          end

          # Try to add 2 more via recurring (total would be 4 > 3)
          tuesday = monday + 1.day
          attrs = {
            room_id: room.id, user_id: regular_user.id, title: "Recurring",
            starts_at: monday.change(hour: 9),
            ends_at: monday.change(hour: 10),
            recurring: "daily",
            recurring_until: tuesday.to_date
          }

          expect { Reservation.create_recurring(attrs) }
            .not_to change(Reservation, :count)
        end
      end

      context 'admin with recurring reservations' do
        it 'allows admin to create recurring beyond 3 active limit' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Admin weekly",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: (monday + 4.weeks).to_date # 5 occurrences
          }

          result = Reservation.create_recurring(attrs)
          expect(result[:success]).to be true
          expect(result[:reservations].size).to eq(5)
        end
      end

      context 'validation edge cases' do
        it 'requires recurring_until when recurring is set' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Weekly",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: nil
          }

          result = Reservation.create_recurring(attrs)
          expect(result[:success]).to be false
          expect(result[:errors]).to include(a_string_matching(/recurring_until/i))
        end

        it 'requires recurring_until to be after starts_at date' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Weekly",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: (monday - 1.week).to_date
          }

          result = Reservation.create_recurring(attrs)
          expect(result[:success]).to be false
        end

        it 'rejects invalid recurring value' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Meeting",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "monthly",
            recurring_until: (monday + 1.month).to_date
          }

          result = Reservation.create_recurring(attrs)
          expect(result[:success]).to be false
          expect(result[:errors]).to include(a_string_matching(/daily.*weekly/i))
        end

        it 'creates a single occurrence when recurring_until equals starts_at date' do
          attrs = {
            room_id: room.id, user_id: user.id, title: "Once",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: monday.to_date
          }

          result = Reservation.create_recurring(attrs)
          expect(result[:success]).to be true
          expect(result[:reservations].size).to eq(1)
        end
      end

      context 'concurrency' do
        it 'uses a transaction so partial saves cannot occur' do
          # Create a blocker on the 3rd occurrence
          third_monday = monday + 2.weeks
          create(:reservation, room: room,
            starts_at: third_monday.change(hour: 10),
            ends_at: third_monday.change(hour: 11))

          attrs = {
            room_id: room.id, user_id: user.id, title: "Weekly",
            starts_at: monday.change(hour: 10),
            ends_at: monday.change(hour: 11),
            recurring: "weekly",
            recurring_until: (monday + 3.weeks).to_date
          }

          count_before = Reservation.count
          Reservation.create_recurring(attrs)
          # Only the blocker should exist, no partial saves
          expect(Reservation.count).to eq(count_before)
        end
      end
    end
  end
end
