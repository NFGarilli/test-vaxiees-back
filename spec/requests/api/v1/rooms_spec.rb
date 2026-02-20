require 'rails_helper'

RSpec.describe "Api::V1::Rooms", type: :request do
  describe "GET /api/v1/rooms" do
    it "returns all rooms" do
      create_list(:room, 3)

      get "/api/v1/rooms"

      expect(response).to have_http_status(:ok)
      expect(parsed_body.size).to eq(3)
    end
  end

  describe "GET /api/v1/rooms/:id" do
    it "returns the room" do
      room = create(:room, name: "Board Room")

      get "/api/v1/rooms/#{room.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_body["name"]).to eq("Board Room")
    end

    it "returns 404 for non-existent room" do
      get "/api/v1/rooms/999"

      expect(response).to have_http_status(:not_found)
      expect(parsed_body["error"]).to match(/not found/i)
    end
  end

  describe "POST /api/v1/rooms" do
    let(:admin) { create(:user, :admin) }
    let(:regular_user) { create(:user) }

    it "creates a room when user is admin" do
      params = { user_id: admin.id, room: { name: "New Room", capacity: 10,
                 has_projector: true, has_video_conference: false, floor: 2 } }

      post "/api/v1/rooms", params: params

      expect(response).to have_http_status(:created)
      expect(parsed_body["name"]).to eq("New Room")
    end

    it "returns forbidden when user is not admin" do
      params = { user_id: regular_user.id, room: { name: "Room", capacity: 5, floor: 1 } }

      post "/api/v1/rooms", params: params

      expect(response).to have_http_status(:forbidden)
      expect(parsed_body["errors"]).to include(a_string_matching(/admin/i))
    end

    it "returns errors for invalid room params" do
      params = { user_id: admin.id, room: { name: "", capacity: -1 } }

      post "/api/v1/rooms", params: params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_body["errors"]).to be_an(Array)
    end

    it "returns 404 for non-existent user_id" do
      params = { user_id: 999, room: { name: "Room", capacity: 5, floor: 1 } }

      post "/api/v1/rooms", params: params

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/rooms/:id/availability" do
    let(:room) { create(:room) }
    let(:monday) { Time.zone.now.next_occurring(:monday) }

    it "returns available slots for a date" do
      create(:reservation, room: room,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 12))

      get "/api/v1/rooms/#{room.id}/availability", params: { date: monday.to_date.to_s }

      expect(response).to have_http_status(:ok)
      expect(parsed_body["available_slots"]).to be_an(Array)
      expect(parsed_body["available_slots"].size).to eq(2) # 9-10, 12-18
    end

    it "returns full day availability when no reservations exist" do
      get "/api/v1/rooms/#{room.id}/availability", params: { date: monday.to_date.to_s }

      expect(response).to have_http_status(:ok)
      expect(parsed_body["available_slots"].size).to eq(1) # 9-18
    end

    it "returns empty slots for a weekend day" do
      saturday = Time.zone.now.next_occurring(:saturday)

      get "/api/v1/rooms/#{room.id}/availability", params: { date: saturday.to_date.to_s }

      expect(response).to have_http_status(:ok)
      expect(parsed_body["available_slots"]).to eq([])
    end

    it "excludes cancelled reservations from availability calculation" do
      create(:reservation, :cancelled, room: room,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 12))

      get "/api/v1/rooms/#{room.id}/availability", params: { date: monday.to_date.to_s }

      expect(response).to have_http_status(:ok)
      expect(parsed_body["available_slots"].size).to eq(1) # Full day available
    end

    it "returns error for invalid date format" do
      get "/api/v1/rooms/#{room.id}/availability", params: { date: "not-a-date" }

      expect(response).to have_http_status(:bad_request)
      expect(parsed_body["errors"]).to include(a_string_matching(/date/i))
    end

    it "returns error when date param is missing" do
      get "/api/v1/rooms/#{room.id}/availability"

      expect(response).to have_http_status(:bad_request)
      expect(parsed_body["errors"]).to include(a_string_matching(/date/i))
    end

    it "returns correct slots with multiple reservations in a day" do
      create(:reservation, room: room,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))
      create(:reservation, room: room,
        starts_at: monday.change(hour: 14),
        ends_at: monday.change(hour: 16))

      get "/api/v1/rooms/#{room.id}/availability", params: { date: monday.to_date.to_s }

      expect(response).to have_http_status(:ok)
      slots = parsed_body["available_slots"]
      expect(slots.size).to eq(3) # 9-10, 11-14, 16-18
    end

    it "returns no available slots when fully booked" do
      create(:reservation, room: room,
        starts_at: monday.change(hour: 9),
        ends_at: monday.change(hour: 13))
      create(:reservation, room: room,
        starts_at: monday.change(hour: 13),
        ends_at: monday.change(hour: 17))
      create(:reservation, room: room,
        starts_at: monday.change(hour: 17),
        ends_at: monday.change(hour: 18))

      get "/api/v1/rooms/#{room.id}/availability", params: { date: monday.to_date.to_s }

      expect(response).to have_http_status(:ok)
      expect(parsed_body["available_slots"]).to eq([])
    end

    it "returns 404 for non-existent room" do
      get "/api/v1/rooms/999/availability", params: { date: monday.to_date.to_s }

      expect(response).to have_http_status(:not_found)
    end
  end

  private

  def parsed_body
    JSON.parse(response.body)
  end
end
