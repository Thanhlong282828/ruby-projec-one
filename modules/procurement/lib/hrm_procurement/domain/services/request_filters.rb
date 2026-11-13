module HrmProcurement
  module Domain
    module Services
      class RequestFilters
        STATUSES = %w[draft submitted approved rejected].freeze
        def self.read(search: nil, status: nil, view: nil, page: nil)
          raise ActiveRecord::RecordNotFound unless search.nil? || (search.is_a?(String) && search.valid_encoding? && search.length <= 120)
          { q: search&.strip, status: Hrm::ListFilters.choice(status, allowed: STATUSES),
            view: Hrm::ListFilters.choice(view, allowed: %w[mine review awaiting_po]), page: page_number(page) }.compact
        end
        def self.page_number(value)
          return 1 if value.nil? || value == ""
          valid = (value.is_a?(Integer) && value.between?(1, 10_000)) || (value.is_a?(String) && value.valid_encoding? && /\A[1-9]\d{0,4}\z/.match?(value) && value.to_i <= 10_000)
          raise ActiveRecord::RecordNotFound unless valid
          value.to_i
        end
        def self.id(value)
          valid = (value.is_a?(Integer) && value.positive?) || (value.is_a?(String) && value.valid_encoding? && /\A[1-9]\d{0,17}\z/.match?(value))
          raise ActiveRecord::RecordNotFound unless valid
          value
        end
      end
    end
  end
end
