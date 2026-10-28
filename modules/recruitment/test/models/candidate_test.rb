require "test_helper"
class CandidateDomainTest < ActiveSupport::TestCase
  test "candidate validates identity and recruiting stage" do
    candidate = Candidate.new(company: fixture_company, full_name: "Applicant", email: "applicant@example.test", position: "Engineer", stage: "unknown")
    assert_not candidate.valid?
    candidate.stage = "interview"
    assert candidate.valid?
  end
end
