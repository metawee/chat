# Single cron entry (config/schedule.yml) that fans out all Shawky periodic work.
class Shawky::ScheduledJobsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    return unless Shawky::Config.enabled?(:routing)

    Account.find_each do |account|
      routing = Shawky::Routing.new(account)
      Shawky::NumberHealthJob.perform_later(account) if routing.configured? && !routing.on_backup?
    end
  end
end
