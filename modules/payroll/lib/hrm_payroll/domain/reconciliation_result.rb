# typed: strict

module HrmPayroll
  module Domain
    # The existing web API is a hash; old/finalized/unauthorized runs have nil projections.
    ReconciliationResult = T.type_alias do
      { source_visible: T::Boolean, finalized: T::Boolean,
       captured: T.nilable(Snapshot), current: T.nilable(Snapshot) }
    end
  end
end
