require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"

class SecretInventoryTest < ActiveSupport::TestCase
  test "force added private env fails before reading contents even when unreadable" do
    Dir.mktmpdir("hrm-secret-inventory-") do |root|
      FileUtils.mkdir_p("#{root}/bin")
      FileUtils.cp(Rails.root.join("bin/check-secrets"), "#{root}/bin/check-secrets")
      secret = "dummy"
      File.write("#{root}/.env", "SECRET_KEY_BASE=#{secret}")
      _, status = Open3.capture2e("git", "-C", root, "init", "-q")
      assert status.success?
      _, status = Open3.capture2e("git", "-C", root, "add", "--", ".env")
      assert status.success?
      File.chmod(0000, "#{root}/.env")
      output, status = Open3.capture2e(RbConfig.ruby, "#{root}/bin/check-secrets")
      assert_equal 1, status.exitstatus
      assert_includes output, "Private configuration must not be publishable: .env"
      assert_not_includes output, secret
    end
  end
end
