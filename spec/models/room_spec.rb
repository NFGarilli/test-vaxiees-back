require 'rails_helper'

RSpec.describe Room, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:reservations).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:room) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:capacity) }
    it { is_expected.to validate_numericality_of(:capacity).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:floor) }
  end
end
