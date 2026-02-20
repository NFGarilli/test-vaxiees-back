require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:reservations).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to validate_presence_of(:max_capacity_allowed) }
    it { is_expected.to validate_numericality_of(:max_capacity_allowed).is_greater_than(0) }

    it 'rejects invalid email format' do
      user = build(:user, email: "not-an-email")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("must be a valid email address")
    end

    it 'accepts valid email format' do
      user = build(:user, email: "valid@example.com")
      expect(user).to be_valid
    end
  end
end
