class Reservation < ApplicationRecord
  belongs_to :room
  belongs_to :user

  scope :active, -> { where(cancelled_at: nil) }
  scope :future, -> { where("starts_at > ?", Time.current) }

  validates :title, presence: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true
  validate :ends_at_after_starts_at
  validate :no_overlapping_reservations
  validate :maximum_duration
  validate :within_business_hours
  validate :room_capacity_for_user
  validate :active_reservation_limit

  def cancel
    if cancelled_at.present?
      errors.add(:base, "Reservation is already cancelled")
      return false
    end

    if Time.current >= starts_at - 60.minutes
      errors.add(:base, "Cannot cancel less than 60 minutes before start time")
      return false
    end

    update(cancelled_at: Time.current)
  end

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

  def maximum_duration
    return if starts_at.nil? || ends_at.nil?

    if ends_at - starts_at > 4.hours
      errors.add(:base, "Reservation cannot last more than 4 hours")
    end
  end

  def within_business_hours
    return if starts_at.nil? || ends_at.nil?

    unless starts_at.on_weekday? && ends_at.on_weekday? &&
           starts_at.hour >= 9 && ends_at.hour <= 18 &&
           (ends_at.hour < 18 || ends_at.min == 0) &&
           starts_at >= starts_at.change(hour: 9, min: 0)
      errors.add(:base, "Reservations must be within business hours (9:00-18:00, Monday-Friday)")
    end
  end

  def room_capacity_for_user
    return if room.nil? || user.nil?
    return if user.is_admin?

    if room.capacity > user.max_capacity_allowed
      errors.add(:base, "Room capacity exceeds your maximum allowed capacity")
    end
  end

  def active_reservation_limit
    return if user.nil?
    return if user.is_admin?

    active_count = Reservation.active.future.where(user_id: user_id)
    active_count = active_count.where.not(id: id) if persisted?

    if active_count.count >= 3
      errors.add(:base, "Cannot have more than 3 active reservations")
    end
  end
end
