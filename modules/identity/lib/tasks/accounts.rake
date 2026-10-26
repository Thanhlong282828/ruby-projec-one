namespace :hrm do
  desc "Create a user: EMAIL=... PASSWORD=... ROLE=employee bundle exec rails hrm:create_user"
  task create_user: :environment do
    user = HrmIdentity::Application::Commands::ManageAccounts.new.create(attributes: { email: ENV.fetch("EMAIL"), password: ENV.fetch("PASSWORD"), role: ENV.fetch("ROLE", "employee") })
    puts "Created user ##{user.id} (#{user.role})"
  end
  desc "Disable an account and revoke API tokens: EMAIL=..."
  task disable_user: :environment do
    HrmIdentity::Application::Commands::ManageAccounts.new.disable(email: ENV.fetch("EMAIL"))
  end
  desc "Remove expired API credentials"
  task purge_tokens: :environment do
    puts HrmIdentity::Application::Commands::ManageAccounts.new.purge_tokens
  end
end
