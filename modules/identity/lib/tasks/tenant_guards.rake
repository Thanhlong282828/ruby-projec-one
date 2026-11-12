namespace :db do
  desc "Verify required tenant membership triggers without changing data"
  task verify_tenant_guards: :environment do
    names = ActiveRecord::Base.connection.select_values("SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE()")
    required = %w[users_membership_insert_guard users_membership_update_guard]
    abort "Membership security triggers missing; complete privileged migration first" unless (required - names).empty?
    puts "Membership database guards: PASS"
  end
end
