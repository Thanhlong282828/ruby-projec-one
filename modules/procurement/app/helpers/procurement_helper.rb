module ProcurementHelper
  def receipt_input_quantity(input, id)
    rows = input[:items]
    rows = rows.values if rows.is_a?(Hash)
    return nil unless rows.is_a?(Array)
    rows.find { |row| row["purchase_order_line_id"].to_s == id.to_s }&.fetch("quantity", nil)
  end

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
  def order_input_price(input, line)
    rows = []
    value = input[:items]
    rows = value.is_a?(Hash) ? value.values : value if value.is_a?(Hash) || value.is_a?(Array)
    row = rows.find { |item| item.is_a?(Hash) && item["source_line_id"].to_s == line.source_line_id.to_s }
    row ? row["unit_price"] : line.unit_price.to_i.to_s
  end
  def purchase_queue_title(view)
    { "review" => "Chờ tôi duyệt", "mine" => "Yêu cầu của tôi", "awaiting_po" => "Phiếu đã duyệt chờ lập PO" }.fetch(view, "Yêu cầu mua hàng")
  end
  def purchase_status_options(view)
    fixed = { "review" => "submitted", "awaiting_po" => "approved" }[view]
    return [ [ purchase_status_label(fixed), fixed ] ] if fixed
    [ [ "Tất cả", "" ] ] + HrmProcurement::Domain::Services::RequestFilters::STATUSES.map { |key| [ purchase_status_label(key), key ] }
  end
end
