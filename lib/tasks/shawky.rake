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
end
