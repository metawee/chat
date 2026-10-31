# One-off setup tasks for a Shawky installation (see docs/shawky/RUNBOOK.ar.md).
namespace :shawky do
  desc 'Apply the Shawky Group name and logos to this installation (Super Admin can still change them later)'
  task branding: :environment do
    {
      'INSTALLATION_NAME' => 'Shawky WhatsApp',
      'BRAND_NAME' => 'Shawky Group',
      'BRAND_URL' => ENV.fetch('FRONTEND_URL'),
      'LOGO_THUMBNAIL' => '/shawky/logo_thumbnail.svg',
      'LOGO' => '/shawky/logo.svg',
      'LOGO_DARK' => '/shawky/logo_dark.svg'
    }.each do |name, value|
      InstallationConfig.find_or_initialize_by(name: name).update!(value: value)
    end
    GlobalConfig.clear_cache
    puts 'Shawky branding applied.'
  end

  desc 'Create the n8n system user (administrator, API only) and print its API token. Usage: rails shawky:n8n_user[ACCOUNT_ID,EMAIL]'
  task :n8n_user, [:account_id, :email] => :environment do |_task, args|
    account = Account.find(args.fetch(:account_id))
    user = User.find_or_initialize_by(email: args.fetch(:email))
    if user.new_record?
      user.assign_attributes(name: 'n8n', password: "#{SecureRandom.base58(24)}aA1!")
      user.skip_confirmation!
      user.save!
    end
    AccountUser.find_or_create_by!(account: account, user: user) { |account_user| account_user.role = :administrator }
    puts "n8n user #{user.email} (id #{user.id}). API token (put it in n8n as the api_access_token header):"
    puts user.access_token.token
  end
end
