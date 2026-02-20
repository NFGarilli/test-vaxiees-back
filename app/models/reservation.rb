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

  # BR7: Creates all occurrences of a recurring reservation atomically.
  # Returns { success: true/false, reservations: [...], errors: [...] }
  def self.create_recurring(attrs)
    recurring = attrs[:recurring]
    recurring_until = attrs[:recurring_until]
    starts_at = attrs[:starts_at]
    ends_at = attrs[:ends_at]

    unless %w[daily weekly].include?(recurring)
      return { success: false, reservations: [], errors: [ "recurring must be daily or weekly" ] }
    end

    if recurring_until.nil?
      return { success: false, reservations: [], errors: [ "recurring_until is required for recurring reservations" ] }
    end

    if starts_at.present? && recurring_until < starts_at.to_date
      return { success: false, reservations: [], errors: [ "recurring_until must be on or after the start date" ] }
    end

    occurrences = build_occurrences(attrs)

    # Validate all occurrences before saving any
    all_errors = validate_occurrences(occurrences)
    if all_errors.any?
      return { success: false, reservations: [], errors: all_errors }
    end

    # Save all in a single transaction with locking
    transaction do
      # Acquire locks once for the entire batch
      lock.where(room_id: attrs[:room_id]).where(cancelled_at: nil).load if attrs[:room_id].present?
      lock.where(user_id: attrs[:user_id]).where(cancelled_at: nil).load if attrs[:user_id].present?

      # Re-validate after acquiring locks to prevent race conditions
      all_errors = validate_occurrences(occurrences)
      if all_errors.any?
        raise ActiveRecord::Rollback
      end

      occurrences.each do |reservation|
        unless reservation.save(validate: false)
          raise ActiveRecord::Rollback
        end
      end
    end

    if all_errors.any?
      return { success: false, reservations: [], errors: all_errors }
    end

    { success: true, reservations: occurrences, errors: [] }
  end

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

  # Wraps save in a transaction with row-level locking to prevent
  # race conditions on overlap (BR1) and active limit (BR5).
  def save(**options, &block)
    return super unless new_record? || changed?

    self.class.transaction do
      if room_id.present?
        self.class.lock.where(room_id: room_id).where(cancelled_at: nil).load
      end

      if user_id.present?
        self.class.lock.where(user_id: user_id).where(cancelled_at: nil).load
      end

      super
    end
  end

  private

  # Builds all occurrence records for a recurring reservation.
  # For daily: skips weekends. For weekly: same weekday each week.
  def self.build_occurrences(attrs)
    starts_at = attrs[:starts_at]
    ends_at = attrs[:ends_at]
    recurring = attrs[:recurring]
    recurring_until = attrs[:recurring_until]
    duration = ends_at - starts_at

    occurrences = []
    current_start = starts_at

    while current_start.to_date <= recurring_until
      if current_start.on_weekday?
        occurrences << new(
          room_id: attrs[:room_id],
          user_id: attrs[:user_id],
          title: attrs[:title],
          starts_at: current_start,
          ends_at: current_start + duration,
          recurring: recurring,
          recurring_until: recurring_until
        )
      end

      current_start += (recurring == "daily" ? 1.day : 1.week)
    end

    occurrences
  end
  private_class_method :build_occurrences

  # Validates all occurrences, including cross-occurrence overlap
  # and cumulative active limit checks.
  def self.validate_occurrences(occurrences)
    errors = []

    occurrences.each_with_index do |reservation, index|
      # Check individual BR1-BR4 validations
      unless reservation.valid?
        reservation.errors.full_messages.each do |msg|
          errors << "Occurrence ##{index + 1}: #{msg}"
        end
      end
    end

    # Check for overlaps between occurrences themselves
    occurrences.each_with_index do |a, i|
      occurrences[(i + 1)..].each_with_index do |b, j|
        if a.room_id == b.room_id && a.starts_at < b.ends_at && a.ends_at > b.starts_at
          errors << "Occurrences ##{i + 1} and ##{i + j + 2} overlap with each other"
        end
      end
    end

    # Check cumulative active reservation limit (BR5) across all occurrences
    if occurrences.any?
      user = occurrences.first.user
      if user.present? && !user.is_admin?
        existing_active = Reservation.active.future.where(user_id: user.id).count
        total = existing_active + occurrences.count
        if total > 3
          errors << "Total recurring occurrences (#{occurrences.count}) plus existing active " \
                    "reservations (#{existing_active}) would exceed the limit of 3 active reservations"
        end
      end
    end

    errors
  end
  private_class_method :validate_occurrences

  def ends_at_after_starts_at
    return if starts_at.nil? || ends_at.nil?

    if ends_at <= starts_at
      errors.add(:ends_at, "must be after starts_at")
    end
  end

  def no_overlapping_reservations
    return if room_id.nil? || starts_at.nil? || ends_at.nil?

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
           (ends_at.hour < 18 || (ends_at.hour == 18 && ends_at.min == 0 && ends_at.sec == 0)) &&
           (starts_at.hour > 9 || (starts_at.hour == 9 && starts_at.min >= 0))
      errors.add(:base, "Reservations must be within business hours (9:00-18:00, Monday-Friday)")
    end
  end

  def room_capacity_for_user
    return if room_id.nil? || user_id.nil?
    return if user.is_admin?

    if room.capacity > user.max_capacity_allowed
      errors.add(:base, "Room capacity exceeds your maximum allowed capacity")
    end
  end

  def active_reservation_limit
    return if user_id.nil?
    return if user.is_admin?

    active_count = Reservation.active.future.where(user_id: user_id)
    active_count = active_count.where.not(id: id) if persisted?

    if active_count.count >= 3
      errors.add(:base, "Cannot have more than 3 active reservations")
    end
  end
end
