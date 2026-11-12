module HrmAttendance
  module Domain
    module Repositories
      class ShiftWriteRepositoryInterface
        def build(company_id:, attributes:)
          raise NotImplementedError, "ShiftWriteRepositoryInterface#build"
        end
        def save!(record:)
          raise NotImplementedError, "ShiftWriteRepositoryInterface#save!"
        end
        def update!(record:, attributes:)
          raise NotImplementedError, "ShiftWriteRepositoryInterface#update!"
        end
        def destroy!(record:)
          raise NotImplementedError, "ShiftWriteRepositoryInterface#destroy!"
        end
      end
    end
  end
end
