# Applies what n8n learned from the CRM about a WhatsApp lead: stores the lead fields on
# the contact and hands the conversation to the CRM owner. The CRM owner wins over round
# robin as long as no agent has written to the customer yet.
# The lead has the same shape as the gateway's (see Shawky::Lead); lead.salesman is the CRM owner.
class Shawky::CrmOwnerAssignment
  REASSIGNABLE_ROUTING = [Shawky::ConversationRouter::AWAITING_CRM_OWNER, 'round_robin', 'round_robin_fallback'].freeze

  pattr_initialize [:conversation!, :lead!]

  def perform
    contact = conversation.contact
    contact.update!(custom_attributes: Shawky::Lead.merge_into(contact.custom_attributes, lead))

    router = Shawky::ConversationRouter.new(conversation: conversation)
    owner = Shawky::CrmUserMapping.user_for(conversation.account, lead['salesman']) if lead['salesman'].present?
    if Shawky::ConversationRouter.active_agent?(owner, conversation)
      hand_to(owner, router) if reassignable?
    elsif router.awaiting_crm_owner?
      router.round_robin('round_robin_after_crm')
    end
    conversation.reload
  end

  private

  def reassignable?
    return true if conversation.assignee_id.nil?

    REASSIGNABLE_ROUTING.include?(conversation.custom_attributes['shawky_routing']) &&
      conversation.messages.outgoing.where(sender_type: 'User').none?
  end

  def hand_to(owner, router)
    previous_assignee_id = conversation.assignee_id
    return if previous_assignee_id == owner.id

    router.assign(owner, 'crm_owner')
    return if previous_assignee_id.nil?

    Shawky::AuditLog.record!('conversation_reassigned', account: conversation.account, auditable: conversation, user: nil,
                                                        metadata: { from_user_id: previous_assignee_id, to_user_id: owner.id, source: 'crm_owner' })
  end
end
