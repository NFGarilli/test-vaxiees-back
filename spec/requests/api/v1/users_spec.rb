require 'rails_helper'

RSpec.describe "Api::V1::Users", type: :request do
  describe "GET /api/v1/users" do
    it "returns all users" do
      create_list(:user, 3)

      get "/api/v1/users"

      expect(response).to have_http_status(:ok)
      expect(parsed_body.size).to eq(3)
    end

    it "returns empty array when no users exist" do
      get "/api/v1/users"

      expect(response).to have_http_status(:ok)
      expect(parsed_body).to eq([])
    end
  end

  describe "GET /api/v1/users/:id" do
    it "returns the user" do
      user = create(:user, name: "Alice")

      get "/api/v1/users/#{user.id}"

      expect(response).to have_http_status(:ok)
      expect(parsed_body["name"]).to eq("Alice")
    end

    it "returns 404 for non-existent user" do
      get "/api/v1/users/999"

      expect(response).to have_http_status(:not_found)
      expect(parsed_body["error"]).to match(/not found/i)
    end
  end

  describe "POST /api/v1/users" do
    it "creates a user with valid params" do
      params = { user: { name: "Bob", email: "bob@example.com", department: "Engineering",
                         max_capacity_allowed: 10, is_admin: false } }

      post "/api/v1/users", params: params

      expect(response).to have_http_status(:created)
      expect(parsed_body["name"]).to eq("Bob")
      expect(parsed_body["email"]).to eq("bob@example.com")
    end

    it "returns errors for invalid params" do
      params = { user: { name: "", email: "" } }

      post "/api/v1/users", params: params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_body["errors"]).to be_an(Array)
      expect(parsed_body["errors"]).not_to be_empty
    end

    it "returns errors for duplicate email" do
      create(:user, email: "taken@example.com")
      params = { user: { name: "Bob", email: "taken@example.com", max_capacity_allowed: 10 } }

      post "/api/v1/users", params: params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(parsed_body["errors"]).to include(a_string_matching(/email/i))
    end
  end

  private

  def parsed_body
    JSON.parse(response.body)
  end
end
