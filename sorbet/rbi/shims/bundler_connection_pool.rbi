# typed: true

# Bundler 2.6 vendors ConnectionPool; gem RBI may reference this real ForkTracker
# module through the vendor alias. Tapioca intentionally excludes Bundler itself.
# No application methods or return types are invented here.
module Bundler
  class ConnectionPool
    module ForkTracker; end
  end
end
