class Room < ApplicationRecord
  has_many :reservations, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :floor, presence: true
end
