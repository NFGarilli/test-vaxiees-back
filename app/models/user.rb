class User < ApplicationRecord
  has_many :reservations, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  validates :max_capacity_allowed, presence: true, numericality: { greater_than: 0 }
end
