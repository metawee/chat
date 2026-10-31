# Single cron entry (config/schedule.yml) that fans out all Shawky periodic work.
class Shawky::ScheduledJobsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    return unless Shawky::Config.enabled?(:routing)

    Account.find_each do |account|
      routing = Shawky::Routing.new(account)
      next unless routing.configured?

      Shawky::NumberHealthJob.perform_later(account) unless routing.on_backup?
      Shawky::ResponseDelayScanJob.perform_later(account)
    end
  end
end
