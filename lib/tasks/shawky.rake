namespace :shawky do
  desc 'Delete ALL data of an account (contract end). Usage: CONFIRM="<account name>" rails shawky:purge_account[ACCOUNT_ID]'
  task :purge_account, [:account_id] => :environment do |_task, args|
    account = Account.find(args.fetch(:account_id))
    abort("Refusing: set CONFIRM to the exact account name (#{account.name.inspect}).") unless ENV['CONFIRM'] == account.name

    report = Shawky::AccountPurge.new(account: account).perform
    Rails.logger.info("[SHAWKY] account purge requested: #{report.to_json}")
    puts "Purge scheduled for account #{account.id} (#{account.name}): #{report.to_json}"
    puts 'Sidekiq deletes the account and its files in the background (DeleteObjectJob); check the logs for completion.'
  end

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
end
