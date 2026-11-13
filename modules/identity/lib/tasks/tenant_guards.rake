namespace :db do
  desc "Verify required membership and purchasing triggers without changing data"
  task verify_tenant_guards: :environment do
    names = ActiveRecord::Base.connection.select_values("SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE()")
    required = %w[users_membership_insert_guard users_membership_update_guard procurement_request_insert_guard procurement_request_update_guard procurement_line_insert_guard procurement_line_update_guard procurement_line_delete_guard]
    abort "Required database triggers missing; complete privileged migration first" unless (required - names).empty?
    puts "Required database guards: PASS"
  end
end
