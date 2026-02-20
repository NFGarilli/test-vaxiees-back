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
end
