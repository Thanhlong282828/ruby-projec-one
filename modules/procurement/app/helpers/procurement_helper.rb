module ProcurementHelper
  def purchase_status_label(status)
    { "draft" => "Bản nháp", "submitted" => "Chờ duyệt", "approved" => "Đã duyệt", "rejected" => "Bị từ chối" }.fetch(status, status)
  end
  def purchase_action_label(action)
    { "created" => "Tạo bản nháp", "updated" => "Sửa bản nháp", "submitted" => "Gửi duyệt", "approved" => "Duyệt", "rejected" => "Từ chối" }.fetch(action, action)
  end
  def purchase_money(amount)
    number_to_currency(amount, unit: "VND", precision: 0, delimiter: ".", format: "%n %u")
  end
  def purchase_form_rows(input)
    rows = HrmProcurement::Domain::Services::RequestContent.rows(input[:items] || [])
    rows.presence || Array.new(3) { {} }
  rescue HrmProcurement::Domain::Services::RequestContent::Invalid
    Array.new(3) { {} }
  end
end
