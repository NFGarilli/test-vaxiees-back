class AddIndexToReservationsForOverlapCheck < ActiveRecord::Migration[8.0]
  def change
    add_index :reservations, [ :room_id, :starts_at, :ends_at ], name: "index_reservations_on_room_and_time"
  end
end
