module Api
  module V1
    class ReservationsController < BaseController
      def index
        reservations = Reservation.includes(:room, :user).order(:starts_at)
        render json: reservations, include: %i[room user]
      end

      def show
        reservation = Reservation.includes(:room, :user).find(params[:id])
        render json: reservation, include: %i[room user]
      end

      def create
        if reservation_params[:recurring].present?
          create_recurring
        else
          create_single
        end
      end

      def cancel
        reservation = Reservation.find(params[:id])

        if reservation.cancel
          render json: reservation
        else
          render_errors(reservation.errors.full_messages)
        end
      end

      private

      def create_single
        reservation = Reservation.new(reservation_params)

        if reservation.save
          render json: reservation, status: :created
        else
          render_errors(reservation.errors.full_messages)
        end
      end

      def create_recurring
        attrs = reservation_params.to_h.symbolize_keys
        attrs[:starts_at] = Time.zone.parse(attrs[:starts_at].to_s) if attrs[:starts_at].present?
        attrs[:ends_at] = Time.zone.parse(attrs[:ends_at].to_s) if attrs[:ends_at].present?
        attrs[:recurring_until] = Date.parse(attrs[:recurring_until].to_s) if attrs[:recurring_until].present?

        result = Reservation.create_recurring(attrs)

        if result[:success]
          render json: result[:reservations], status: :created
        else
          render_errors(result[:errors])
        end
      end

      def reservation_params
        params.require(:reservation).permit(
          :room_id, :user_id, :title, :starts_at, :ends_at,
          :recurring, :recurring_until
        )
      end
    end
  end
end
