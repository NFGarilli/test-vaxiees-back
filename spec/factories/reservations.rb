FactoryBot.define do
  factory :reservation do
    room
    user
    title { "Team meeting" }
    # Default: next Monday from 10:00 to 11:00
    starts_at { Time.zone.now.next_occurring(:monday).change(hour: 10, min: 0) }
    ends_at { Time.zone.now.next_occurring(:monday).change(hour: 11, min: 0) }
    recurring { nil }
    recurring_until { nil }
    cancelled_at { nil }

    trait :cancelled do
      cancelled_at { Time.zone.now }
    end

    trait :weekly do
      recurring { 'weekly' }
      recurring_until { 4.weeks.from_now.to_date }
    end

    trait :daily do
      recurring { 'daily' }
      recurring_until { 1.week.from_now.to_date }
    end

    trait :long do
      # 3 hours (valid)
      ends_at { Time.zone.now.next_occurring(:monday).change(hour: 13, min: 0) }
    end

    trait :too_long do
      # 5 hours (invalid)
      ends_at { Time.zone.now.next_occurring(:monday).change(hour: 15, min: 0) }
    end
  end
end
