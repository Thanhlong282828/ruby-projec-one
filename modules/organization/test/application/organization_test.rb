require "test_helper"
require "csv"
class OrganizationTest < ActiveSupport::TestCase
  def setup
    super
    @admin = make_user(:admin)
  end
  def create(resource, attributes, actor: @admin)
    HrmOrganization::Application::Commands::CreateRecord.new.call(actor: actor, resource: resource, attributes: attributes)
  end
  def revise(resource, record, attributes)
    HrmOrganization::Application::Commands::UpdateRecord.new.call(actor: @admin, resource: resource, id: record.id, attributes: attributes)
  end
  def unit(code = "ROOT", **attrs)
    create("organization_units", { code: code, name: code, unit_type: "company", headcount_limit: 10, effective_from: Date.current }.merge(attrs))
  end
  def position(parent, code = "ENG", **attrs)
    create("job_positions", { code: code, title: code, organization_unit_id: parent.id, career_level: 2, approved_headcount: 2 }.merge(attrs))
  end
  test "module bindings and provisioning give new companies database grants" do
    assert_instance_of HrmOrganization::Infrastructure::Persistence::ActiveRecordReadRepository, Hrm::Container.resolve(HrmOrganization::Domain::Repositories::ReadRepositoryInterface)
    company = Company.create!(code: "ORGNEW", name: "New company")
    admin = make_user(:admin, company: company)
    assert admin.allowed?("organization_units.create")
    assert admin.allowed?("employee_assignments.delete")
    assert make_user(:hr, company: company).allowed?("cost_centers.export")
    assert_not make_user(:hr, company: company).allowed?("cost_centers.delete")
    assert_not make_user(:employee, company: company).allowed?("organization_units.read")
  end
  test "permission revoke and user deny apply to direct commands" do
    employee = make_user
    assert_raises(Pundit::NotAuthorizedError) { create("cost_centers", { code: "NO", name: "No" }, actor: employee) }
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "cost_centers.create"), granted: false)
    assert_no_difference [ "CostCenter.count", "AuditLog.count", "OutboxEvent.count" ] do
      assert_raises(Pundit::NotAuthorizedError) { create("cost_centers", { code: "NO", name: "No" }) }
    end
  end
  test "commands take company from actor and strip unrecognized attributes" do
    other = Company.create!(code: "OTHER", name: "Other")
    record = create("cost_centers", { code: "CC", name: "Own", company_id: other.id, id: 999_999 })
    assert_equal @admin.company_id, record.company_id
    assert_not_equal 999_999, record.id
    assert_equal 1, AuditLog.where(record_type: "CostCenter", record_id: record.id).count
    assert_equal 1, OutboxEvent.where(company_id: @admin.company_id, event_type: "cost_center.created").count
  end
  test "tree and direct lookup isolate companies and forbid cross company writes" do
    own = unit
    other_admin = make_user(:admin, company: Company.create!(code: "ORGOTHER", name: "Other"))
    other = create("organization_units", { code: "OTHER", name: "Other", unit_type: "company", effective_from: Date.current }, actor: other_admin)
    rows = HrmOrganization::Application::Queries::ListRecords.new.call(actor: @admin, resource: "organization_units")
    assert_equal [ own.id ], rows.map(&:id)
    assert_raises(ActiveRecord::RecordNotFound) { revise("organization_units", other, { name: "Leak" }) }
    assert_raises(ActiveRecord::RecordInvalid) { unit("CROSS", unit_type: "branch", parent_id: other.id) }
    tree = HrmOrganization::Application::Queries::Structure.new.call(actor: @admin, view: :tree)
    assert_equal([ own.id ], tree.pluck(:id))
  end
  test "hierarchy rejects cycles self parent and moving to higher level" do
    root = unit
    child = unit("BRANCH", unit_type: "branch", parent_id: root.id)
    team = unit("TEAM", unit_type: "team", parent_id: child.id)
    assert_raises(ActiveRecord::RecordInvalid) { revise("organization_units", root, { parent_id: team.id }) }
    assert_raises(ActiveRecord::RecordInvalid) { revise("organization_units", root, { parent_id: root.id }) }
    assert_raises(ActiveRecord::RecordInvalid) { revise("organization_units", child, { unit_type: "company" }) }
    assert_raises(ActiveRecord::RecordInvalid) { revise("organization_units", child, { unit_type: "team" }) }
    assert_nil root.reload.parent_id
    assert_equal "branch", child.reload.unit_type
  end
  test "valid move persists and tree links point to canonical source" do
    left = unit("LEFT")
    right = unit("RIGHT")
    branch = unit("BRANCH", unit_type: "branch", parent_id: left.id)
    revise("organization_units", branch, { parent_id: right.id })
    tree = HrmOrganization::Application::Queries::Structure.new.call(actor: @admin, view: :tree)
    row = tree.detect { |x| x[:id] == right.id }[:children].first
    assert_equal branch.id, row[:id]
    assert_equal "/organization/organization-units/#{branch.id}", row[:source]
  end
  test "database composite foreign keys reject bypassed tenant associations" do
    own = unit
    other = Company.create!(code: "CROSSDB", name: "Other")
    center = CostCenter.create!(company: other, code: "FOREIGN", name: "Foreign")
    assert_raises(ActiveRecord::InvalidForeignKey) { OrganizationUnit.where(id: own.id).update_all(cost_center_id: center.id) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
  end
  test "company unique codes do not prevent other companies reusing codes" do
    create("cost_centers", { code: "SAME", name: "One" })
    assert_raises(ActiveRecord::RecordInvalid) { create("cost_centers", { code: "SAME", name: "Duplicate" }) }
    actor = make_user(:admin, company: Company.create!(code: "SEPARATE", name: "Other"))
    record = create("cost_centers", { code: "SAME", name: "Two" }, actor: actor)
    assert_equal actor.company_id, record.company_id
  end
  test "deleting a referenced cost center unit position or employee is restricted" do
    cc = create("cost_centers", { code: "CC", name: "Center" })
    org = unit(cost_center_id: cc.id)
    job = position(org)
    employee = make_employee
    create("employee_assignments", { employee_id: employee.id, organization_unit_id: org.id, job_position_id: job.id, effective_from: Date.current })
    [ [ "cost_centers", cc ], [ "organization_units", org ], [ "job_positions", job ] ].each do |resource, record|
      assert_raises(ActiveRecord::RecordNotDestroyed) { HrmOrganization::Application::Commands::DeleteRecord.new.call(actor: @admin, resource: resource, id: record.id) }
    end
    assert_not employee.destroy
    assert employee.errors.any?
  end
  test "allocation and headcount consider all overlapping future intervals" do
    org = unit
    job = position(org, approved_headcount: 1)
    employee = make_employee
    from = Date.current + 20
    attributes = { employee_id: employee.id, organization_unit_id: org.id, job_position_id: job.id, effective_from: from, effective_to: from + 10, allocation_percent: 100 }
    create("employee_assignments", attributes)
    assert_raises(ActiveRecord::RecordInvalid) { create("employee_assignments", attributes.merge(effective_from: from + 5)) }
    second = make_employee
    assert_raises(ActiveRecord::RecordInvalid) { create("employee_assignments", attributes.merge(employee_id: second.id)) }
    assert_raises(ActiveRecord::RecordInvalid) { revise("job_positions", job, { approved_headcount: 0 }) }
    later = create("employee_assignments", attributes.merge(employee_id: second.id, effective_from: from + 11, effective_to: nil))
    assert later.persisted?
  end
  test "two partial assignments are allowed up to one hundred percent" do
    org = unit
    employee = make_employee
    first = position(org, "ONE")
    second = position(org, "TWO")
    attrs = { employee_id: employee.id, organization_unit_id: org.id, effective_from: Date.current, allocation_percent: 50 }
    create("employee_assignments", attrs.merge(job_position_id: first.id))
    create("employee_assignments", attrs.merge(job_position_id: second.id))
    assert_raises(ActiveRecord::RecordInvalid) { create("employee_assignments", attrs.merge(job_position_id: second.id, allocation_percent: 1)) }
  end
  test "assignment must use matching position unit and company" do
    first, second = unit("ONE"), unit("TWO")
    job = position(first)
    employee = make_employee
    assert_raises(ActiveRecord::RecordInvalid) { create("employee_assignments", { employee_id: employee.id, organization_unit_id: second.id, job_position_id: job.id, effective_from: Date.current }) }
  end
  test "headcount counts only active assignments and links to their source" do
    org = unit
    job = position(org, approved_headcount: 3)
    create("employee_assignments", { employee_id: make_employee.id, organization_unit_id: org.id, job_position_id: job.id, effective_from: Date.current })
    row = HrmOrganization::Application::Queries::Structure.new.call(actor: @admin, view: :headcount).first
    assert_equal [ 3, 1, 2 ], row.values_at(:approved, :occupied, :vacant)
    assert_equal "/organization/job-positions/#{job.id}", row[:source]
    assert_equal "/organization/organization-units/#{org.id}", row[:unit_source]
  end
  test "CSV export is tenant scoped and neutralizes spreadsheet formulas" do
    create("cost_centers", { code: "SAFE", name: '=HYPERLINK("http://invalid")' })
    other_actor = make_user(:admin, company: Company.create!(code: "EXPORTOTHER", name: "Other"))
    create("cost_centers", { code: "HIDDEN", name: "Other" }, actor: other_actor)
    csv = HrmOrganization::Application::Queries::ExportRecords.new.call(actor: @admin, resource: "cost_centers")
    rows = CSV.parse(csv, headers: true)
    assert_equal 1, rows.length
    assert rows.first["name"].start_with?("'=")
    assert_not_includes csv, "HIDDEN"
    assert_raises(Pundit::NotAuthorizedError) { HrmOrganization::Application::Queries::ExportRecords.new.call(actor: make_user, resource: "cost_centers") }
  end
  test "request allowlist rejects company and arbitrary model fields" do
    params = ActionController::Parameters.new(record: { name: "Name", code: "CODE", company_id: 999, role: "admin", created_at: "2000-01-01" })
    assert_equal({ name: "Name", code: "CODE" }, HrmOrganization::Application::Requests::RecordRequest.read(params, resource: "cost_centers"))
    assert_raises(ActiveRecord::RecordNotFound) { HrmOrganization::Domain::Resources.model("User") }
  end
  test "invalid numeric date and currency inputs leave no audit or outbox" do
    assert_no_difference [ "CostCenter.count", "AuditLog.count", "OutboxEvent.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { create("cost_centers", { code: "BAD", name: "Bad", annual_budget: -1, currency: "XXX" }) }
    end
    assert_raises(ActiveRecord::RecordInvalid) { unit(effective_to: Date.current - 1) }
  end
end

class OrganizationTest
  test "optional foreign ids must exist and fail as validation rather than SQL errors" do
    assert_raises(ActiveRecord::RecordInvalid) { unit(parent_id: 9_999_999) }
    assert_raises(ActiveRecord::RecordInvalid) { unit(cost_center_id: 9_999_999) }
  end
  test "existing staffing lineage prevents moving occupied positions to another unit" do
    source, target = unit("SOURCE"), unit("TARGET")
    job = position(source)
    create("employee_assignments", { employee_id: make_employee.id, organization_unit_id: source.id, job_position_id: job.id, effective_from: Date.current })
    assert_raises(ActiveRecord::RecordInvalid) { revise("job_positions", job, { organization_unit_id: target.id }) }
    assert_equal source.id, job.reload.organization_unit_id
  end
  test "assignment dates must respect employee and unit validity" do
    org = unit(effective_from: Date.current, effective_to: Date.current + 10)
    job = position(org)
    employee = make_employee
    attributes = { employee_id: employee.id, organization_unit_id: org.id, job_position_id: job.id, effective_from: Date.current }
    assert_raises(ActiveRecord::RecordInvalid) { create("employee_assignments", attributes) }
    assert_raises(ActiveRecord::RecordInvalid) { create("employee_assignments", attributes.merge(effective_from: Date.current - 1, effective_to: Date.current + 5)) }
    employee.update!(status: :inactive)
    assert_raises(ActiveRecord::RecordInvalid) { create("employee_assignments", attributes.merge(effective_to: Date.current + 5)) }
  end
  test "workspace resolves canonical related names and source links through query" do
    cc = create("cost_centers", { code: "CC", name: "Engineering cost center" })
    org = unit(cost_center_id: cc.id)
    data = HrmOrganization::Application::Queries::Workspace.new.call(actor: @admin, resource: "organization_units", id: org.id)
    field = data[:fields].detect { |value| value[:label] == "Trung tâm chi phí" }
    assert_equal cc.name, field[:value]
    assert_equal "/organization/cost-centers/#{cc.id}", field[:source]
    @admin.user_permissions.create!(permission: Permission.find_by!(key: "cost_centers.read"), granted: false)
    data = HrmOrganization::Application::Queries::Workspace.new.call(actor: @admin, resource: "organization_units", id: org.id)
    assert_nil data[:fields].detect { |value| value[:label] == "Trung tâm chi phí" }[:source]
  end
end

class OrganizationTest
  test "database enforces position unit lineage even when validation is bypassed" do
    source, target = unit("SOURCE"), unit("TARGET")
    job = position(source)
    record = create("employee_assignments", { employee_id: make_employee.id, organization_unit_id: source.id, job_position_id: job.id, effective_from: Date.current })
    assert_raises(ActiveRecord::InvalidForeignKey) { EmployeeAssignment.where(id: record.id).update_all(organization_unit_id: target.id) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_raises(ActiveRecord::InvalidForeignKey) { JobPosition.where(id: job.id).update_all(organization_unit_id: target.id) } # rubocop:disable Rails/SkipsModelValidations -- Regression intentionally exercises DB guards or corrupt/legacy rows without AR callbacks.
    assert_equal source.id, record.reload.organization_unit_id
  end
end

class OrganizationTest
  test "identity provisioning can operate without an organization catalog and registration is reload safe" do
    previous = Rails.application.config.x.hrm.permission_catalogs
    begin
      Rails.application.config.x.hrm.permission_catalogs = []
      company = Company.create!(code: "BASEONLY", name: "Base identity")
      assert_equal 29, company.company_roles.find_by!(key: "admin").permissions.count
      2.times { HrmOrganization::Providers::OrganizationServiceProvider.new.register }
      assert_equal [ "HrmOrganization::Domain::PermissionDefinitions" ], Rails.application.config.x.hrm.permission_catalogs
      assert_equal 51, HrmIdentity::Domain::PermissionCatalog.definitions.length
    ensure
      Rails.application.config.x.hrm.permission_catalogs = previous
    end
  end
end
