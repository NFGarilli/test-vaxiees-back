module Api
  module V1
    class RoomsController < BaseController
      def index
        rooms = Room.all
        render json: rooms
      end

      def show
        room = Room.find(params[:id])
        render json: room
      end

      def create
        user = User.find(params[:user_id])

        unless user.is_admin?
          return render_errors("Only administrators can create rooms", status: :forbidden)
        end

        room = Room.new(room_params)

        if room.save
          render json: room, status: :created
        else
          render_errors(room.errors.full_messages)
        end
      end

      def availability
        room = Room.find(params[:id])
        date = Date.parse(params[:date])

        reservations = room.reservations.active
          .where("starts_at >= ? AND starts_at < ?", date.beginning_of_day, date.end_of_day)
          .order(:starts_at)

        slots = build_availability_slots(date, reservations)

        render json: { room_id: room.id, date: date.to_s, available_slots: slots, reservations: reservations }
      rescue Date::Error
        render_errors("Invalid date format. Use YYYY-MM-DD", status: :bad_request)
      end

      private

      def room_params
        params.require(:room).permit(:name, :capacity, :has_projector, :has_video_conference, :floor)
      end

      def build_availability_slots(date, reservations)
        return [] unless date.on_weekday?

        day_start = date.in_time_zone.change(hour: 9)
        day_end = date.in_time_zone.change(hour: 18)
        slots = []
        current = day_start

        reservations.each do |res|
          if current < res.starts_at
            slots << { starts_at: current, ends_at: res.starts_at }
          end
          current = [ current, res.ends_at ].max
        end

        slots << { starts_at: current, ends_at: day_end } if current < day_end
        slots
      end
    end
  end
end
