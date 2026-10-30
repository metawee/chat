# Delivers a Shawky::CrmActivity to the CRM. Unreachable/429/5xx responses are retried with
# growing delays; other errors (bad signature, invalid payload) will not fix themselves.
class Shawky::CrmActivityJob < ApplicationJob
  queue_as :default

  retry_on Shawky::Crm::Error, wait: :polynomially_longer, attempts: 10 do |job, error|
    job.arguments.first.update!(status: :failed, last_error: error.message)
  end

  def perform(activity)
    return if activity.delivered?

    activity.increment!(:attempts) # rubocop:disable Rails/SkipsModelValidations
    Shawky::Crm::Client.new.post_activity(activity.payload)
    activity.update!(status: :delivered, delivered_at: Time.current, last_error: nil)
  rescue Shawky::Crm::Error => e
    activity.update!(last_error: e.message)
    raise if e.retryable?

    activity.update!(status: :failed)
  end
end
