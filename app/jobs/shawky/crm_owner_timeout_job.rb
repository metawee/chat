# n8n did not report a CRM owner in time: hand the new lead to round robin.
class Shawky::CrmOwnerTimeoutJob < ApplicationJob
  queue_as :high

  def perform(conversation)
    router = Shawky::ConversationRouter.new(conversation: conversation)
    return unless router.awaiting_crm_owner? && conversation.assignee_id.nil?

    router.round_robin('round_robin_fallback')
  end
end
