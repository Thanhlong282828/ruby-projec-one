require "test_helper"
class SecurityHttpTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = make_user(:admin)
  end
  def login
    post "/session", params: { email: @user.email, password: "StrongPassword123!" }
    assert_redirected_to root_path
  end
  test "replaying copied encrypted cookie after logout cannot authenticate" do
    login
    copied = cookies["_xinviec_hrm"]
    assert copied.present?
    delete "/session"
    cookies["_xinviec_hrm"] = copied
    get "/"
    assert_redirected_to new_session_path
  end
  test "web session expires on server even if browser keeps cookie" do
    login
    travel 8.hours + 1.second do
      get "/"
      assert_redirected_to new_session_path
    end
  end
  test "password change invalidates existing browser login" do
    login
    @user.update!(password: "OtherStrongPassword123!")
    get "/"
    assert_redirected_to new_session_path
  end
  test "sensitive web and token responses must not be cached" do
    get "/session/new"
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Content-Security-Policy"], "form-action 'self'"
    assert_equal "same-origin", response.headers["Cross-Origin-Opener-Policy"]
    post "/api/v1/session", params: { email: @user.email, password: "StrongPassword123!" }, as: :json
    assert_response :created
    assert_includes response.headers["Cache-Control"], "no-store"
  end
  test "CSRF protection rejects web mutations without a token" do
    old = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post "/session", params: { email: @user.email, password: "StrongPassword123!" }
    assert_response :unprocessable_entity
    assert_equal 0, @user.login_sessions.count
  ensure
    ActionController::Base.allow_forgery_protection = old
  end
  test "HR sensitive input is filtered before request logging" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    result = filter.filter({ "password" => "secret", "national_id" => "0123456789",
      "bank_account" => "123456789", "salary_cents" => 999999, "reason" => "private" })
    assert(result.values.all?("[FILTERED]"))
  end
end
