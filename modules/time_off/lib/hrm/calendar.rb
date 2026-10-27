module Hrm
  # Pure Ruby domain utility, independent of controllers and persistence.
  module Calendar
    module_function

    def inclusive_days(starts_on, ends_on)
      raise ArgumentError, "End date precedes start date" if ends_on < starts_on
      (ends_on - starts_on).to_i + 1
    end
  end
end
