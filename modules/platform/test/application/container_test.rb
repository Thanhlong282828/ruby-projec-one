require "test_helper"
class ContainerArchitectureTest < ActiveSupport::TestCase
  test "every module provider resolves concrete implementations of its contracts" do
    contracts = Dir[Rails.root.join("modules/*/lib/hrm_*/domain/repositories/*_interface.rb")]
    assert_equal 17, contracts.length
    contracts.each do |file|
      relative = file.split("/lib/", 2).last.delete_suffix(".rb")
      contract = relative.camelize.constantize
      implementation = Hrm::Container.resolve(contract)
      assert_kind_of contract, implementation
      contract.instance_methods(false).each do |method|
        assert_not_equal contract, implementation.method(method).owner, "#{contract}##{method} is still abstract"
      end
    end
  end
  test "container does not silently construct an unregistered contract" do
    assert_raises(Hrm::Container::MissingBinding) { Hrm::Container.new.resolve("MissingRepositoryInterface") }
  end
  test "invalid binding fails rather than bypassing a contract" do
    container = Hrm::Container.new
    container.bind(HrmAttendance::Domain::Repositories::ReadRepositoryInterface, implementation: "String")
    assert_raises(Hrm::Container::InvalidBinding) { container.resolve(HrmAttendance::Domain::Repositories::ReadRepositoryInterface) }
  end
  test "bindings retain names and each resolution gets a fresh repository" do
    assert Hrm::Container.bindings.all? { |key, value| key.is_a?(String) && value.is_a?(String) }
    contract = HrmAttendance::Domain::Repositories::ReadRepositoryInterface
    assert_not_same Hrm::Container.resolve(contract), Hrm::Container.resolve(contract)
  end
end
