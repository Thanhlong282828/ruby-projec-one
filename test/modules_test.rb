# Rails' default test command also executes every local engine's tests.
Dir[Rails.root.join("modules/*/test/**/*_test.rb")].sort.each { |file| require file }
