# Picks the first assignee of a new conversation on the Shawky numbers:
# 1. a returning customer goes back to their previous agent while that agent is still active;
# 2. a brand-new lead waits for n8n to report the CRM owner (Shawky::Hooks::N8nController),
#    with Shawky::CrmOwnerTimeoutJob falling back to round robin;
# 3. everyone else goes to round robin over online inbox members.
class Shawky::ConversationRouter
  AWAITING_CRM_OWNER = 'awaiting_crm_owner'.freeze

  pattr_initialize [:conversation!]

  def self.active_agent?(user, conversation)
    user.present? && conversation.account.users.exists?(id: user.id) && conversation.inbox.inbox_members.exists?(user_id: user.id)
  end

  def route
    previous_agent = conversation.contact.conversations.where.not(id: conversation.id).where.not(assignee_id: nil).order(:created_at).last&.assignee
    return assign(previous_agent, 'returning_customer') if self.class.active_agent?(previous_agent, conversation)
    return await_crm_owner if new_lead?

    round_robin('round_robin')
  end

  def assign(user, source)
    mark(source)
    conversation.update!(assignee: user)
  end

  def round_robin(source)
    mark(source)
    AutoAssignment::AgentAssignmentService.new(
      conversation: conversation, allowed_agent_ids: conversation.inbox.member_ids_with_assignment_capacity
    ).perform
  end

  def awaiting_crm_owner?
    conversation.custom_attributes['shawky_routing'] == AWAITING_CRM_OWNER
  end

  def mark(source)
    conversation.update_columns(custom_attributes: conversation.custom_attributes.merge('shawky_routing' => source)) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def new_lead?
    conversation.contact.conversations.where.not(id: conversation.id).none? && Shawky::Lead.id(conversation.contact).blank?
  end

  def await_crm_owner
    mark(AWAITING_CRM_OWNER)
    wait = Shawky::Routing.new(conversation.account).crm_owner_wait
    conversation_record = conversation
    ActiveRecord.after_all_transactions_commit { Shawky::CrmOwnerTimeoutJob.set(wait: wait).perform_later(conversation_record) }
  end
end
