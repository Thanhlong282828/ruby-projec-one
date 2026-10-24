module Payroll
  class FinalizeRun
    def self.call(run:, actor:)
      raise Pundit::NotAuthorizedError unless actor&.active? && actor.staff?
      run.with_lock do
        raise TimeOff::Review::InvalidTransition, "Already finalized" unless run.draft?
        raise TimeOff::Review::InvalidTransition, "Cannot finalize an empty payroll" unless run.payslips.exists?
        run.update!(status: :finalized, finalized_at: Time.current)
      end
    end
  end
end
