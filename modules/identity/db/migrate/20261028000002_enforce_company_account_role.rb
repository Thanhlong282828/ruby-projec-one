class EnforceCompanyAccountRole < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :users, :company_roles, column: [:company_id, :role], primary_key: [:company_id, :key], name: "fk_users_company_role"
  end
end
