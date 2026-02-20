class AddIndexToReservationsForUserActiveCount < ActiveRecord::Migration[8.0]
  def change
    add_index :reservations, [ :user_id, :cancelled_at, :starts_at ], name: "index_reservations_on_user_active_future"
  end
end
