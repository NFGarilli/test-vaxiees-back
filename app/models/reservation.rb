class Reservation < ApplicationRecord
  belongs_to :room
  belongs_to :user

  scope :active, -> { where(cancelled_at: nil) }

  validates :title, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_starts_at
  validate :no_overlapping_reservations

  private

  def ends_at_after_starts_at
    return if starts_at.nil? || ends_at.nil?

    if ends_at <= starts_at
      errors.add(:ends_at, "must be after starts_at")
    end
  end

  def no_overlapping_reservations
    return if room.nil? || starts_at.nil? || ends_at.nil?

    overlapping = Reservation.active
      .where(room_id: room_id)
      .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)

    overlapping = overlapping.where.not(id: id) if persisted?

    if overlapping.exists?
      errors.add(:base, "Room already has an overlapping reservation for this time period")
    end
  end
end
