module Payroll
  class BuildRun
    def self.call(period:, actor:)
      HrmPayroll::Application::Commands::BuildPayRun.new.call(period: period, actor: actor)
    end
  end
end
