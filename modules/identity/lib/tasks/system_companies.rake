namespace :system do
  desc "Trusted local CLI: grant installation owner rights to an existing login identity"
  task grant_owner: :environment do
    Hrm::Container.resolve(HrmIdentity::Domain::Repositories::TenantWriteRepositoryInterface).grant_system_owner!(email: ENV.fetch("EMAIL"))
    puts "System owner provisioned in MySQL. No password or token changed."
  end
end
