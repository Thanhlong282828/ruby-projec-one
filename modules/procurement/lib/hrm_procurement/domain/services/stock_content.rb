require "digest"
module HrmProcurement
  module Domain
    module Services
      class StockContent
        def self.catalog(attributes, kind:)
          raise RequestContent::Invalid, "Dữ liệu danh mục không hợp lệ" unless attributes.is_a?(Hash)
          raise RequestContent::Invalid, "Danh mục không hợp lệ" unless %i[warehouse item].include?(kind)
          code = RequestContent.text(attributes[:code], "Mã", 40).upcase
          raise RequestContent::Invalid, "Mã chỉ gồm chữ, số, _ và -" unless /\A[A-Z0-9][A-Z0-9_-]*\z/.match?(code)
          raise RequestContent::Invalid, "Trạng thái không hợp lệ" unless %w[active inactive].include?(attributes[:status])
          result = { code: code, name: RequestContent.text(attributes[:name], "Tên", 200), status: attributes[:status] }
          result[:unit] = RequestContent.text(attributes[:unit], "Đơn vị", 30) if kind == :item
          result
        end
        def self.mapping(attributes)
          raise RequestContent::Invalid, "Dữ liệu nhập không hợp lệ" unless attributes.is_a?(Hash)
          warehouse_id = RequestFilters.id(attributes[:warehouse_id]).to_i
          rows = attributes[:items]
          rows = rows.values if rows.is_a?(Hash) && rows.keys.all? { |key| /\A\d{1,4}\z/.match?(key.to_s) }
          raise RequestContent::Invalid, "Cần ánh xạ đầy đủ các dòng nhận" unless rows.is_a?(Array) && rows.size.between?(1, 50) && rows.all?(Hash)
          items = rows.map do |row|
            row = row.stringify_keys
            { goods_receipt_line_id: RequestFilters.id(row["goods_receipt_line_id"]).to_i, stock_item_id: RequestFilters.id(row["stock_item_id"]).to_i }
          end.sort_by { |row| row[:goods_receipt_line_id] }
          raise RequestContent::Invalid, "Dòng nhận bị lặp" unless items.pluck(:goods_receipt_line_id).uniq.size == items.size
          { warehouse_id: warehouse_id, items: items }
        end
        def self.digest(receipt_id, content)
          Digest::SHA256.hexdigest(JSON.generate([ receipt_id, content[:warehouse_id], content[:items].map { |row| [ row[:goods_receipt_line_id], row[:stock_item_id] ] } ]))
        end
      end
    end
  end
end
