# typed: true
# frozen_string_literal: true

# Add your extra requires here (`bin/tapioca require` can be used to bootstrap this list)

# Public optional APIs used by jobs/tests, not loaded by their primary gem entrypoints.
require "sidekiq/api"
require "minitest/mock"
