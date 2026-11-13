require "test_helper"
require "tmpdir"
require "fileutils"
require "open3"

class ArchitectureGateTest < ActiveSupport::TestCase
  def fixture
    Dir.mktmpdir("hrm-architecture-") do |root|
      FileUtils.mkdir_p("#{root}/config")
      FileUtils.cp(Rails.root.join("config/engine_boundaries.yml"), "#{root}/config/engine_boundaries.yml")
      YAML.safe_load_file(Rails.root.join("config/engine_boundaries.yml")).fetch("engines").each_key do |engine|
        FileUtils.mkdir_p("#{root}/modules/#{engine}/lib/hrm_#{engine}")
        File.write("#{root}/modules/#{engine}/lib/hrm_#{engine}/engine.rb", "")
      end
      yield root
    end
  end

  def write(root, path, source)
    file = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, source)
  end

  def check(root)
    Open3.capture2e(RbConfig.ruby, Rails.root.join("bin/check-architecture").to_s, root)
  end

  test "controller persistence bypass is rejected rather than accepted as CQRS" do
    fixture do |root|
      _, status = check(root)
      assert status.success?
      write(root, "modules/payroll/app/controllers/leak_controller.rb", "class LeakController; def index; Hrm::Container.resolve(Object); end; end")
      output, status = check(root)
      assert_not status.success?
      assert_includes output, "controllers must use Command/Query"
    end
  end

  test "missing binding and cross engine implementation are rejected" do
    fixture do |root|
      write(root, "modules/payroll/lib/hrm_payroll/domain/repositories/read_repository_interface.rb", "")
      output, status = check(root)
      assert_not status.success?
      assert_includes output, "missing explicit provider binding"
      write(root, "modules/payroll/lib/hrm_payroll/providers/payroll_service_provider.rb", 'bind "HrmPayroll::Domain::Repositories::ReadRepositoryInterface", "HrmIdentity::Infrastructure::Persistence::Reader"')
      output, status = check(root)
      assert_not status.success?
      assert_includes output, "binding crosses ownership"
    end
  end

  test "Payroll cannot instantiate Leave infrastructure or gain undeclared IAM dependencies" do
    fixture do |root|
      write(root, "modules/payroll/lib/hrm_payroll/application/commands/bypass.rb", "HrmTimeOff::Infrastructure::Persistence::Writer.new; HrmIdentity::Domain::Repositories::ReadRepositoryInterface")
      output, status = check(root)
      assert_not status.success?
      assert_includes output, "forbidden cross-engine Infrastructure"
      assert_includes output, "undeclared dependency on HrmIdentity"
    end
  end
end
