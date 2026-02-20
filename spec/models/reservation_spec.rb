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
end
