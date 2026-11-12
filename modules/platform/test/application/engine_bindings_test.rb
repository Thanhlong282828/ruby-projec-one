require "test_helper"

class EngineBindingsTest < ActiveSupport::TestCase
  test "all installed engines load and every provider resolves its owned contract" do
    Rails.application.eager_load!
    engines = Rails::Engine.subclasses.select { |engine| engine.name.start_with?("Hrm") }
    assert_equal 12, engines.size
    contracts = Rails.root.glob("modules/*/lib/*/domain/repositories/*_interface.rb").map do |file|
      parts = file.to_s.split("/")
      namespace = parts[parts.index("lib") + 1].camelize
      "#{namespace}::Domain::Repositories::#{File.basename(file, ".rb").camelize}"
    end
    assert_equal contracts.sort, Hrm::Container.bindings.keys.sort
    contracts.each do |name|
      contract = name.constantize
      instance = Hrm::Container.resolve(contract)
      assert_kind_of contract, instance
      assert_equal contract.name.split("::").first, instance.class.name.split("::").first
    end
  end
end
