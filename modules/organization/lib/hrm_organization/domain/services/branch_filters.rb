module HrmOrganization
  module Domain
    module Services
      class BranchFilters
        class Invalid < ArgumentError; end
        attr_reader :q, :status, :after

        def initialize(q: nil, status: nil, after: nil)
          raise Invalid, "Từ khóa phải là chuỗi tối đa 100 ký tự." unless q.nil? || (q.is_a?(String) && q.valid_encoding? && q.length <= 100)
          raise Invalid, "Trạng thái chi nhánh không hợp lệ." unless status.nil? || (status.is_a?(String) && %w[all current upcoming ended].include?(status))
          unless after.nil? || (after.is_a?(String) && /\A[1-9][0-9]{0,17}\z/.match?(after))
            raise Invalid, "Mốc phân trang không hợp lệ."
          end
          @q = q.to_s.strip
          @status = status || "all"
          @after = after&.to_i
        end
      end
    end
  end
end
