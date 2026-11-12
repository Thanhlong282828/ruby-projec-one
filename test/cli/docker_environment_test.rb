require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"

class DockerEnvironmentTest < ActiveSupport::TestCase
  test "env bootstrap generates a private random Rails key and preserves an existing env" do
    Dir.mktmpdir("hrm-env-bootstrap-") do |root|
      FileUtils.mkdir_p("#{root}/bin")
      FileUtils.cp(Rails.root.join("bin/setup-docker"), "#{root}/bin/setup-docker")
      FileUtils.cp(Rails.root.join(".env.example"), "#{root}/.env.example")
      output, status = Open3.capture2e(RbConfig.ruby, "#{root}/bin/setup-docker", "--env-only")
      assert status.success?, "Environment bootstrap failed (output withheld)"
      path = "#{root}/.env"
      contents = File.read(path)
      secret = contents.lines.find { |line| line.start_with?("SECRET_KEY_BASE=") }.split("=", 2).last.strip
      assert_match(/\A[0-9a-f]{128}\z/, secret)
      assert_not_includes output, secret
      assert_equal 0600, File.stat(path).mode & 0777
      _, status = Open3.capture2e(RbConfig.ruby, "#{root}/bin/setup-docker", "--env-only")
      assert status.success?
      assert_equal contents, File.read(path)
    end
  end
end
