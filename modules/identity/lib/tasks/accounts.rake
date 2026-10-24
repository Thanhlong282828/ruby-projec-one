namespace :hrm do
  desc "Create a user: EMAIL=... PASSWORD=... ROLE=employee bundle exec rails hrm:create_user"
  task create_user: :environment do
    user = User.create!(email: ENV.fetch("EMAIL"), password: ENV.fetch("PASSWORD"), role: ENV.fetch("ROLE", "employee"))
    puts "Created user ##{user.id} (#{user.role})"
  end
  desc "Disable an account and revoke API tokens: EMAIL=..."
  task disable_user: :environment do
    User.transaction do
      user = User.find_by!(email: ENV.fetch("EMAIL").strip.downcase)
      user.update!(active: false)
      user.api_tokens.destroy_all
    end
  end
  desc "Remove expired API credentials"
  task purge_tokens: :environment do
    puts ApiToken.where("expires_at < ?", Time.current).delete_all
  end
end
