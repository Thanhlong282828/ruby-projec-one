# Rails' default test command also executes every local engine's tests.
Rails.root.glob("modules/*/test/**/*_test.rb").each { |file| require file }
