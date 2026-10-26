module Hrm
  module Pagination
    module_function
    def call(scope, page)
      scope.limit(25).offset(([page.to_i, 1].max - 1) * 25)
    end
  end
end
