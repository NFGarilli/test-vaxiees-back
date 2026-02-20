require 'rails_helper'

RSpec.describe "Api::V1::Reservations", type: :request do
  let(:monday) { Time.zone.now.next_occurring(:monday) }

  describe "GET /api/v1/reservations" do
    it "returns all reservations with room and user included" do
      create_list(:reservation, 2,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      get "/api/v1/reservations"

      expect(response).to have_http_status(:ok)
      expect(parsed_body.size).to eq(2)
      expect(parsed_body.first).to have_key("room_id")
      expect(parsed_body.first).to have_key("user_id")
    end

    it "returns reservations ordered by starts_at" do
      create(:reservation,
        starts_at: monday.change(hour: 14),
        ends_at: monday.change(hour: 15))
      create(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      get "/api/v1/reservations"

      starts = parsed_body.map { |r| r["starts_at"] }
      expect(starts).to eq(starts.sort)
    end
  end

  describe "GET /api/v1/reservations/:id" do
    it "returns the reservation" do
      reservation = create(:reservation, title: "Standup",
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      get "/api/v1/reservations/#{reservation.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_body["title"]).to eq("Standup")
    end

    it "returns 404 for non-existent reservation" do
      get "/api/v1/reservations/999"

      expect(response).to have_http_status(:not_found)
      expect(parsed_body["error"]).to match(/not found/i)
    end
  end

  describe "POST /api/v1/reservations" do
    let(:room) { create(:room) }
    let(:user) { create(:user) }

    context "single reservation" do
      it "creates a reservation with valid params" do
        params = { reservation: {
          room_id: room.id, user_id: user.id, title: "Meeting",
          starts_at: monday.change(hour: 10).iso8601,
          ends_at: monday.change(hour: 11).iso8601
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:created)
        expect(parsed_body["title"]).to eq("Meeting")
      end

      it "returns validation errors for overlapping reservation (BR1)" do
        create(:reservation, room: room,
          starts_at: monday.change(hour: 10),
          ends_at: monday.change(hour: 12))

        params = { reservation: {
          room_id: room.id, user_id: user.id, title: "Overlap",
          starts_at: monday.change(hour: 11).iso8601,
          ends_at: monday.change(hour: 13).iso8601
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to include(a_string_matching(/overlap/i))
      end

      it "returns validation errors for exceeding duration (BR2)" do
        params = { reservation: {
          room_id: room.id, user_id: user.id, title: "Long",
          starts_at: monday.change(hour: 9).iso8601,
          ends_at: monday.change(hour: 14).iso8601
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to include(a_string_matching(/4 hours/i))
      end

      it "returns validation errors for outside business hours (BR3)" do
        saturday = Time.zone.now.next_occurring(:saturday)
        params = { reservation: {
          room_id: room.id, user_id: user.id, title: "Weekend",
          starts_at: saturday.change(hour: 10).iso8601,
          ends_at: saturday.change(hour: 11).iso8601
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to include(a_string_matching(/business hours/i))
      end

      it "returns validation errors for capacity restriction (BR4)" do
        limited_user = create(:user, max_capacity_allowed: 5)
        big_room = create(:room, capacity: 20)

        params = { reservation: {
          room_id: big_room.id, user_id: limited_user.id, title: "Too big",
          starts_at: monday.change(hour: 10).iso8601,
          ends_at: monday.change(hour: 11).iso8601
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to include(a_string_matching(/capacity/i))
      end

      it "returns validation errors for active reservation limit (BR5)" do
        3.times do |i|
          create(:reservation, user: user,
            starts_at: monday.change(hour: 10 + i),
            ends_at: monday.change(hour: 11 + i))
        end

        params = { reservation: {
          room_id: room.id, user_id: user.id, title: "4th",
          starts_at: monday.change(hour: 14).iso8601,
          ends_at: monday.change(hour: 15).iso8601
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to include(a_string_matching(/3 active/i))
      end

      it "returns error for missing params" do
        post "/api/v1/reservations", params: {}

        expect(response).to have_http_status(:bad_request)
        expect(parsed_body["error"]).to match(/missing parameter/i)
      end
    end

    context "recurring reservation (BR7)" do
      let(:admin) { create(:user, :admin) }

      it "creates multiple reservations for weekly recurrence" do
        params = { reservation: {
          room_id: room.id, user_id: admin.id, title: "Weekly standup",
          starts_at: monday.change(hour: 10).iso8601,
          ends_at: monday.change(hour: 11).iso8601,
          recurring: "weekly",
          recurring_until: (monday + 2.weeks).to_date.to_s
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:created)
        expect(parsed_body.size).to eq(3)
      end

      it "returns errors when any occurrence is invalid" do
        # Block the 2nd week
        create(:reservation, room: room,
          starts_at: (monday + 1.week).change(hour: 10),
          ends_at: (monday + 1.week).change(hour: 11))

        params = { reservation: {
          room_id: room.id, user_id: admin.id, title: "Blocked",
          starts_at: monday.change(hour: 10).iso8601,
          ends_at: monday.change(hour: 11).iso8601,
          recurring: "weekly",
          recurring_until: (monday + 2.weeks).to_date.to_s
        } }

        post "/api/v1/reservations", params: params

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to be_present
        expect(Reservation.where(title: "Blocked").count).to eq(0)
      end
    end
  end

  describe "PATCH /api/v1/reservations/:id/cancel" do
    it "cancels a reservation successfully (BR6)" do
      reservation = create(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      travel_to monday.change(hour: 8) do
        patch "/api/v1/reservations/#{reservation.id}/cancel"

        expect(response).to have_http_status(:ok)
        expect(parsed_body["cancelled_at"]).not_to be_nil
      end
    end

    it "returns errors when cancelling too late" do
      reservation = create(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      travel_to monday.change(hour: 9, min: 30) do
        patch "/api/v1/reservations/#{reservation.id}/cancel"

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to include(a_string_matching(/60 minutes/i))
      end
    end

    it "returns errors when already cancelled" do
      reservation = create(:reservation,
        starts_at: monday.change(hour: 10),
        ends_at: monday.change(hour: 11))

      travel_to monday.change(hour: 8) do
        patch "/api/v1/reservations/#{reservation.id}/cancel"
        patch "/api/v1/reservations/#{reservation.id}/cancel"

        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed_body["errors"]).to include(a_string_matching(/already cancelled/i))
      end
    end

    it "returns 404 for non-existent reservation" do
      patch "/api/v1/reservations/999/cancel"

      expect(response).to have_http_status(:not_found)
    end
  end

  private

  def parsed_body
    JSON.parse(response.body)
  end
end
