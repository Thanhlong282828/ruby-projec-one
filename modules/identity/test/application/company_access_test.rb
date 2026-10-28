require "test_helper"
class CompanyAccessTest < ActiveSupport::TestCase
  def another_company
    Company.create!(code: "OTHER#{SecureRandom.hex(3).upcase}", name: "Other Company")
  end
  def administration = Hrm::Container.resolve(HrmIdentity::Domain::Repositories::AdministrationRepositoryInterface)
  def override(user, key, granted)
    user.user_permissions.create!(permission: Permission.find_by!(key: key), granted: granted)
  end
  test "role grants and per-account deny are persisted in MySQL and take effect immediately" do
    user = make_user
    permission = Permission.find_by!(key: "payroll.read")
    role = user.company.company_roles.find_by!(key: user.role)
    assert_not user.allowed?("payroll.read")
    link = RolePermission.create!(company_role: role, permission: permission)
    assert user.allowed?("payroll.read")
    override(user, "payroll.read", false)
    assert_not user.allowed?("payroll.read")
    user.user_permissions.destroy_all
    assert user.allowed?("payroll.read")
    link.destroy!
    assert_not user.allowed?("payroll.read")
    override(user, "payroll.read", true)
    assert user.allowed?("payroll.read")
    assert_equal "Mysql2", ActiveRecord::Base.connection.adapter_name
  end
  test "role grants are separate per company and admins have no wildcard bypass" do
    admin = make_user(:admin)
    other = make_user(:admin, company: another_company)
    override(admin, "employees.read_all", false)
    assert_not admin.allowed?("employees.read_all")
    assert other.allowed?("employees.read_all")
    role = admin.company.company_roles.find_by!(key: "employee")
    RolePermission.create!(company_role: role, permission: Permission.find_by!(key: "payroll.read"))
    assert make_user(:employee, company: admin.company).allowed?("payroll.read")
    assert_not make_user(:employee, company: other.company).allowed?("payroll.read")
  end
  test "staff scopes and direct commands cannot cross company boundaries" do
    admin = make_user(:admin)
    other_admin = make_user(:admin, company: another_company)
    own = make_employee
    other = make_employee(make_user(:employee, company: other_admin.company))
    assert_equal [own.id], Pundit.policy_scope!(admin, Employee).pluck(:id)
    assert_equal [own.department_id], Pundit.policy_scope!(admin, Department).pluck(:id)
    assert_raises(ActiveRecord::RecordNotFound) { HrmWorkforce::Application::Queries::FindEmployee.new.call(actor: admin, id: other.id) }
    assert_raises(Pundit::NotAuthorizedError) { HrmWorkforce::Application::Commands::UpdateEmployee.new.call(actor: admin, record: other, attributes: { full_name: "Hijacked" }) }
    assert_equal "Test Person", other.reload.full_name
    record = HrmWorkforce::Application::Commands::CreateDepartment.new.call(actor: admin, attributes: { code: "OWN", name: "Owned", company_id: other.company_id })
    assert_equal admin.company_id, record.company_id
  end
  test "MySQL rejects cross company association even when model validations are bypassed" do
    own = make_employee
    other = make_employee(make_user(:employee, company: another_company))
    assert_raises(ActiveRecord::InvalidForeignKey) { own.update_column(:department_id, other.department_id) }
    assert_equal own.company_id, own.reload.department.company_id
    assert_raises(ActiveRecord::InvalidForeignKey) do
      User.connection.execute("UPDATE users SET role='unknown-role' WHERE id=#{own.user_id}")
    end
  end
  test "company identifiers can repeat but records cannot be moved between companies" do
    first = make_employee(employee_code: "DUP")
    second = make_employee(make_user(:employee, company: another_company), employee_code: "DUP", email: first.email)
    assert second.persisted?
    second.company = first.company
    assert_not second.valid?
  end
  test "department and user form options contain only current company records" do
    admin = make_user(:admin)
    own = make_employee
    other = make_employee(make_user(:employee, company: another_company))
    options = HrmWorkforce::Application::Queries::EmployeeFormOptions.new.call(actor: admin)
    assert_equal [own.department_id], options[:departments].map(&:id)
    assert_includes options[:users].map(&:id), own.user_id
    assert_not_includes options[:users].map(&:id), other.user_id
  end
  test "foreign department and account cannot be attached through create employee command" do
    admin = make_user(:admin)
    other = make_employee(make_user(:employee, company: another_company))
    assert_raises(ActiveRecord::RecordInvalid) do
      HrmWorkforce::Application::Commands::CreateEmployee.new.call(actor: admin, attributes: { department_id: other.department_id, user_id: other.user_id, employee_code: "CROSS", full_name: "Cross", email: "cross@example.test", job_title: "Engineer", hired_on: Date.current })
    end
  end
  test "payroll company isolation includes employee snapshots and tenant unique period" do
    admin = make_user(:admin)
    other_admin = make_user(:admin, company: another_company)
    own = make_employee
    other = make_employee(make_user(:employee, company: other_admin.company))
    run = HrmPayroll::Application::Commands::BuildPayRun.new.call(period: Date.current, actor: admin)
    other_run = HrmPayroll::Application::Commands::BuildPayRun.new.call(period: Date.current, actor: other_admin)
    assert_equal [own.id], run.payslips.pluck(:employee_id)
    assert_equal [other.id], other_run.payslips.pluck(:employee_id)
    assert_raises(Pundit::NotAuthorizedError) { HrmPayroll::Application::Commands::FinalizePayRun.new.call(run: other_run, actor: admin) }
  end
  test "dashboard cache does not mix company data and permission revocation changes its key" do
    admin = make_user(:admin)
    other_admin = make_user(:admin, company: another_company)
    make_employee
    2.times { make_employee(make_user(:employee, company: other_admin.company)) }
    query = HrmDashboard::Application::Queries::Overview.new
    assert_equal 1, query.call(actor: admin)[:employees]
    assert_equal 2, query.call(actor: other_admin)[:employees]
    override(admin, "employees.read_all", false)
    assert_equal 0, query.call(actor: admin)[:employees]
    assert_equal 2, query.call(actor: other_admin)[:employees]
  end
  test "audit outbox and scheduled summaries carry company identity" do
    admin = make_user(:admin)
    other_admin = make_user(:admin, company: another_company)
    own = make_employee
    other = make_employee(make_user(:employee, company: other_admin.company))
    request = own.leave_requests.create!(starts_on: Date.current, ends_on: Date.current, reason: "Own")
    2.times do |i|
      day = Date.current + 10 + i * 2
      other.leave_requests.create!(starts_on: day, ends_on: day, reason: "Other")
    end
    assert_equal [own.company_id], AuditLog.where(record_type: "Employee", record_id: own.id).pluck(:company_id).uniq
    event = OutboxEvent.where(event_type: "employee.created").detect { |row| row.payload["record_id"] == own.id }
    assert_equal own.company_id, event.company_id
    summary = HrmTimeOff::Application::Queries::DailySummary.new.call(company_id: own.company_id)
    assert_equal 1, summary[:pending]
    assert summary[:recipients].all? { |user| user.company_id == own.company_id }
    assert_equal 2, HrmTimeOff::Application::Queries::DailySummary.new.call(company_id: other.company_id)[:pending]
    repository = Hrm::Container.resolve(HrmTimeOff::Domain::Repositories::ReadRepositoryInterface)
    assert_raises(ActiveRecord::RecordNotFound) { repository.find_for_mail!(id: request.id, company_id: other.company_id) }
  end
  test "company admin can assign account role and grants with audit trail" do
    admin = make_user(:admin)
    employee = make_user
    administration.update_account!(actor: admin, id: employee.id, attributes: { role: "manager", permission_overrides: { "recruitment.read" => "grant", "leave.review" => "deny" } })
    assert employee.reload.manager?
    assert employee.allowed?("recruitment.read")
    assert_not employee.allowed?("leave.review")
    assert AuditLog.where(company_id: admin.company_id, record_type: "User", record_id: employee.id, action: "account.access.updated").exists?
    administration.update_account!(actor: admin, id: employee.id, attributes: { active: true })
    assert_not employee.allowed?("leave.review"), "omitting override fields must preserve existing denies"
  end
  test "account management rejects foreign IDs unknown permission keys and self changes" do
    admin = make_user(:admin)
    own = make_user
    other = make_user(:employee, company: another_company)
    assert_raises(ActiveRecord::RecordNotFound) { administration.update_account!(actor: admin, id: other.id, attributes: { role: "admin" }) }
    assert_raises(HrmIdentity::Domain::InvalidAdministration) { administration.update_account!(actor: admin, id: own.id, attributes: { permission_overrides: { "unknown.permission" => "grant" } }) }
    assert_raises(HrmIdentity::Domain::InvalidAdministration) { administration.update_account!(actor: admin, id: admin.id, attributes: { role: "employee" }) }
    assert_raises(Pundit::NotAuthorizedError) { administration.update_account!(actor: own, id: admin.id, attributes: { role: "employee" }) }
  end
  test "role management persists changes and keeps protected admin capabilities" do
    admin = make_user(:admin)
    employee = make_user
    role = admin.company.company_roles.find_by!(key: "employee")
    administration.update_role!(actor: admin, id: role.id, attributes: { name: "Reader", permission_keys: %w[dashboard.view payroll.read] })
    assert employee.allowed?("payroll.read")
    assert_not employee.allowed?("attendance.clock")
    protected_role = admin.company.company_roles.find_by!(key: "admin")
    assert_raises(HrmIdentity::Domain::InvalidAdministration) { administration.update_role!(actor: admin, id: protected_role.id, attributes: { permission_keys: [] }) }
    other_role = another_company.company_roles.first
    assert_raises(ActiveRecord::RecordNotFound) { administration.update_role!(actor: admin, id: other_role.id, attributes: { permission_keys: [] }) }
  end
  test "provisioning company and admin is atomic and stores actual role permission rows" do
    before_count = Company.count
    assert_raises(ActiveRecord::RecordInvalid) { administration.create_company!(code: "INVALID", name: "Invalid", owner_email: "invalid@example.test", password: "short") }
    assert_equal before_count, Company.count
    company = administration.create_company!(code: "NEWORG", name: "New Org", owner_email: "owner-new@example.test", password: "StrongPassword123!")
    assert_equal 4, company.company_roles.count
    assert_equal 29, company.company_roles.find_by!(key: "admin").permissions.count
    assert company.users.first.allowed?("accounts.manage")
  end
  test "general employee edit grant cannot leak or change protected compensation fields" do
    actor = make_user
    employee = make_employee
    override(actor, "employees.update", true)
    override(actor, "employees.read_all", true)
    assert_not EmployeePolicy.new(actor, employee).sensitive?
    assert_raises(Pundit::NotAuthorizedError) { HrmWorkforce::Application::Commands::UpdateEmployee.new.call(actor: actor, record: employee, attributes: { salary_cents: 1 }) }
    assert_equal 20000000, employee.reload.salary_cents
  end
  test "custom roles live in MySQL and can be assigned without changing application enums" do
    admin = make_user(:admin)
    employee = make_user
    role = administration.update_role!(actor: admin, id: nil, attributes: { key: "team_lead", name: "Trưởng nhóm", permission_keys: %w[dashboard.view employees.read_all leave.read_all leave.review] })
    assert_equal admin.company_id, role.company_id
    administration.update_account!(actor: admin, id: employee.id, attributes: { role: "team_lead" })
    assert_equal "team_lead", employee.reload.role
    assert employee.allowed?("leave.review")
    assert employee.allowed?("employees.read_all")
    assert_not employee.allowed?("accounts.manage")
    assert_equal role.id, CompanyRole.find_by!(company_id: employee.company_id, key: employee.role).id
  end

  test "stale actor cannot mint a token after account or company deactivation" do
    actor = make_user
    User.where(id: actor.id).update_all(active: false)
    assert actor.active?, "test intentionally keeps the old object in memory"
    assert_raises(Pundit::NotAuthorizedError) { HrmIdentity::Application::Commands::IssueToken.new.call(actor: actor) }
    actor.reload.update!(active: true)
    Company.where(id: actor.company_id).update_all(active: false)
    assert_raises(Pundit::NotAuthorizedError) { HrmIdentity::Application::Commands::IssueToken.new.call(actor: actor) }
  end

end
