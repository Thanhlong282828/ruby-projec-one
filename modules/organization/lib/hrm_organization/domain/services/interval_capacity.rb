module HrmOrganization
  module Domain
    module Services
      # Pure interval sweep. Date intervals include both endpoints; nil means open-ended.
      class IntervalCapacity
        def self.peak(intervals)
          events = Hash.new(0)
          intervals.each do |from, to, amount|
            next unless from
            events[from] += amount
            events[to + 1] -= amount if to
          end
          running = 0
          events.sort.reduce(0) { |maximum, (_, delta)| running += delta; [ maximum, running ].max }
        end
      end
    end
  end
end
