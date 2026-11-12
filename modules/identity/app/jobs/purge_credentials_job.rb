class PurgeCredentialsJob < ApplicationJob
  def perform
    HrmIdentity::Application::Commands::ManageAccounts.new.purge_tokens
  end
end
