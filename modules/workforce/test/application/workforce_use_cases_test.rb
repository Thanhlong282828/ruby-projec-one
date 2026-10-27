require "test_helper"
class WorkforceUseCasesTest < ActiveSupport::TestCase
  test "employee cannot invoke employee creation command directly" do
    actor = make_user
    assert_raises(Pundit::NotAuthorizedError) do
      HrmWorkforce::Application::Commands::CreateEmployee.new.call(actor: actor, attributes: { full_name: "Unauthorized" })
    end
  end
  test "form option query is restricted to staff" do
    assert_raises(Pundit::NotAuthorizedError) { HrmWorkforce::Application::Queries::EmployeeFormOptions.new.call(actor: make_user) }
  end
  test "API request allowlist excludes linked user and encrypted identity fields" do
    params = ActionController::Parameters.new(employee: { full_name: "Allowed", user_id: 999, national_id: "private", role: "admin", bank_account: "private" })
    result = HrmWorkforce::Application::Requests::EmployeeRequest.read(params, api: true)
    assert_equal({ full_name: "Allowed" }, result)
  end
end
