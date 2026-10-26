module Payroll
  class FinalizeRun
    def self.call(run:, actor:)
      HrmPayroll::Application::Commands::FinalizePayRun.new.call(run: run, actor: actor)
    end
  end
end
