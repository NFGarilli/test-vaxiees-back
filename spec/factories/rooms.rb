FactoryBot.define do
  factory :room do
    sequence(:name) { |n| "Room #{n}" }
    capacity { 10 }
    has_projector { false }
    has_video_conference { false }
    floor { 1 }

    trait :with_projector do
      has_projector { true }
    end

    trait :with_video_conference do
      has_video_conference { true }
    end

    trait :fully_equipped do
      has_projector { true }
      has_video_conference { true }
    end

    trait :small do
      capacity { 4 }
    end

    trait :large do
      capacity { 20 }
    end
  end
end
