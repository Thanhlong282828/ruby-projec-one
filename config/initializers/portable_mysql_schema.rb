require "active_record/tasks/mysql_database_tasks"
require "open3"

# Keep trigger DDL, but never pin a checked-in schema to a local DB account or
# auto-increment counters. No data rows are included by Rails structure_dump.
module PortableMysqlSchema
  def structure_load(filename, extra_flags)
    super
    # Some mysql clients keep processing SOURCE after an SQL error and exit 0.
    # Refuse a seemingly successful load that silently omitted security triggers.
    if File.read(filename).include?("users_membership_insert_guard")
      names = connection.select_values("SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE()")
      required = %w[users_membership_insert_guard users_membership_update_guard]
      if File.read(filename).include?("procurement_request_insert_guard")
        required += %w[procurement_request_insert_guard procurement_request_update_guard procurement_line_insert_guard procurement_line_update_guard procurement_line_delete_guard]
      end
      if File.read(filename).include?("purchase_order_insert_guard")
        required += %w[supplier_identity_guard purchase_order_insert_guard purchase_order_update_guard purchase_order_line_insert_guard purchase_order_line_update_guard purchase_order_line_delete_guard]
      end
      if File.read(filename).include?("goods_receipt_insert_guard")
        required += %w[goods_receipt_insert_guard goods_receipt_update_guard goods_receipt_delete_guard goods_receipt_line_insert_guard goods_receipt_line_update_guard goods_receipt_line_delete_guard]
      end
      if File.read(filename).include?("stock_receipt_insert_guard")
        required += %w[warehouses_identity_guard stock_items_identity_guard stock_receipt_insert_guard stock_receipt_update_guard stock_receipt_delete_guard stock_movement_insert_guard stock_movement_update_guard stock_movement_delete_guard]
      end
      raise "Schema load missing required security triggers; use the migration role" unless (required - names).empty?
    end
  end
  def structure_dump(filename, extra_flags)
    super
    sql = File.read(filename)
    sql = sql.lines.reject { |line| line.start_with?("/*M!999999") }.join
    sql = sql.gsub(/DEFINER=`[^`]*`@`[^`]*`/, "")
    sql = sql.gsub(/ AUTO_INCREMENT=\d+/, "")
    File.write(filename, sql.rstrip + "\n")
  end
  private
  def prepare_command_options
    options = super
    version, status = Open3.capture2("mysql", "--version")
    if status.success? && version.include?("MariaDB")
      # Same verification, connector-specific flag; never disable peer checking.
      options.map { |arg| arg == "--ssl-mode=verify_identity" ? "--ssl-verify-server-cert" : arg }
    else
      options
    end
  end
end
ActiveRecord::Tasks::MySQLDatabaseTasks.prepend(PortableMysqlSchema)

ca = ENV["DATABASE_SSL_CA"]
local_ca = Rails.root.join("tmp/mysql-schema-client/ca.pem")
ca ||= local_ca.to_s if File.file?(local_ca)
ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = [ "--no-tablespaces" ] + (ca ? [ "--ssl-ca=#{ca}" ] : [])
ActiveRecord::Tasks::DatabaseTasks.structure_load_flags = ca ? [ "--ssl-ca=#{ca}" ] : []
