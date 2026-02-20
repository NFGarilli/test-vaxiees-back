module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ActiveRecord::RecordNotFound do |e|
        render json: { error: "#{e.model || 'Record'} not found" }, status: :not_found
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: "Missing parameter: #{e.param}" }, status: :bad_request
      end

      private

      def render_errors(errors, status: :unprocessable_entity)
        render json: { errors: Array(errors) }, status: status
      end
    end
  end
end
