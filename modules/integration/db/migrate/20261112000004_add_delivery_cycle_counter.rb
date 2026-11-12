class AddDeliveryCycleCounter < ActiveRecord::Migration[8.1]
  def change
    add_column :integration_deliveries, :cycle_attempt_count, :integer, null: false, default: 0
    add_check_constraint :integration_deliveries, "cycle_attempt_count >= 0 AND cycle_attempt_count <= 5", name: "delivery_cycle_bounds"
    add_check_constraint :integration_deliveries, "(status = 'delivered' AND delivered_at IS NOT NULL) OR (status <> 'delivered' AND delivered_at IS NULL)", name: "delivery_completion_time"
    add_check_constraint :integration_delivery_attempts, "sequence >= 1 AND sequence <= 55 AND (http_status IS NULL OR (http_status >= 100 AND http_status <= 599)) AND completed_at >= started_at", name: "delivery_attempt_validity"
  end
end
