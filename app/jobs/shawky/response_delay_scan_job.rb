# R4: finds assigned, open conversations on the Shawky numbers whose customer has been
# waiting longer than the configured delay, and alerts once per wait.
class Shawky::ResponseDelayScanJob < ApplicationJob
  queue_as :low

  def perform(account)
    routing = Shawky::Routing.new(account)
    return unless routing.configured?

    account.conversations.open.where(inbox_id: routing.managed_inbox_ids).where.not(assignee_id: nil)
           .where(waiting_since: ..routing.reply_delay.ago).find_each do |conversation|
      next if Shawky::DelayAlert.exists?(conversation: conversation, waiting_since: conversation.waiting_since)

      Shawky::ResponseDelayAlert.new(conversation: conversation, routing: routing).perform
    end
  end
end
