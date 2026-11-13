module ProcurementFixtures
  def purchase_commands = HrmProcurement::Application::Commands
  def purchase_attributes(title: "Office supplies")
    { title: title, purpose: "Sample operational need", needed_on: (Date.current + 7).iso8601,
      items: [ { "description" => "Notebooks", "quantity" => "1.125", "unit" => "box", "estimated_unit_price" => "1000" },
              { "description" => "Sample portion", "quantity" => "0.001", "unit" => "kg", "estimated_unit_price" => "500" } ] }
  end
  def create_purchase(actor, title: "Office supplies") = purchase_commands::CreateRequest.new.call(actor: actor, attributes: purchase_attributes(title: title))
  def submit_purchase(actor, record)
    purchase_commands::SubmitRequest.new.call(actor: actor, id: record.id, lock_version: record.lock_version)
  end
  def decide_purchase(actor, record, decision: "approved", reason: nil, version: record.lock_version)
    purchase_commands::DecideRequest.new.call(actor: actor, id: record.id, decision: decision, reason: reason, lock_version: version)
  end
  def purchase_login(user)
    post "/session", params: { email: user.email, password: "StrongPassword123!" }
    assert_response :redirect
  end
end
