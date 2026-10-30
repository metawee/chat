# Opens the WhatsApp conversation for a lead launched from the CRM "WhatsApp" button.
# Only the lead's CRM owner (or their supervisor) may open it. The CRM owner gets the
# conversation, even if it sat with someone else.
class Shawky::CrmLaunch
  class NotAllowed < StandardError; end
  class InvalidLead < StandardError; end

  pattr_initialize [:account!, :user!, :lead!]

  def perform
    agent = Shawky::CrmUserMapping.user_for(account, lead.dig('agent', 'id'))
    raise NotAllowed unless agent && (user == agent || supervises?(agent))

    phone = Shawky::PhoneNumber.e164(lead['whatsapp'].presence || lead['mobile'])
    raise InvalidLead if phone.blank?

    conversation = conversation_for(contact_for(phone), agent)
    Shawky::AuditLog.record!('crm_launch', account: account, user: user, auditable: conversation,
                                           metadata: { lead_id: lead['lead_id'], crm_agent_id: lead.dig('agent', 'id') })
    conversation
  end

  private

  def supervises?(agent)
    Shawky::TeamSupervisor.where(account: account, user: user).exists?(team_id: TeamMember.where(user_id: agent.id).select(:team_id))
  end

  def contact_for(phone)
    lead_attributes = lead.slice(*Shawky::CrmOwnerAssignment::LEAD_ATTRIBUTES)
    contact = account.contacts.find_by(phone_number: phone) || account.contacts.new(phone_number: phone)
    contact.name = lead['name'] if lead['name'].present? && (contact.name.blank? || Shawky::PhoneMask.phone_like?(contact.name))
    contact.name ||= phone
    contact.custom_attributes = (contact.custom_attributes || {}).merge(lead_attributes)
    contact.save!
    contact
  end

  def conversation_for(contact, agent)
    inbox = Shawky::Routing.new(account).active_inbox
    existing = contact.conversations.where(inbox: inbox).where.not(status: :resolved).order(:created_at).last
    return hand_to(existing, agent) if existing

    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    account.conversations.create!(inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: agent)
  end

  def hand_to(conversation, agent)
    previous_assignee_id = conversation.assignee_id
    return conversation if previous_assignee_id == agent.id

    conversation.update!(assignee: agent)
    if previous_assignee_id
      metadata = { from_user_id: previous_assignee_id, to_user_id: agent.id, source: 'crm_launch' }
      Shawky::AuditLog.record!('conversation_reassigned', account: account, auditable: conversation, user: user, metadata: metadata)
    end
    conversation
  end
end
