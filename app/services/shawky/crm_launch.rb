# Opens the WhatsApp conversation for a lead claimed from the Shawky gateway (CRM "واتساب" button).
# Allowed for the lead's salesman (mapped CRM username), their team supervisor, or an administrator.
# The conversation always goes to the salesman, even if it sat with someone else.
class Shawky::CrmLaunch
  class NotAllowed < StandardError; end
  class InvalidLead < StandardError; end

  pattr_initialize [:account!, :user!, :lead!, :session_id]

  def perform
    salesman = Shawky::CrmUserMapping.user_for(account, lead['salesman'].to_s.strip)
    raise NotAllowed unless salesman && allowed?(salesman)

    phone = Shawky::PhoneNumber.e164(lead['phone'])
    raise InvalidLead if phone.blank?

    contact = contact_for(phone)
    conversation = conversation_for(contact, salesman)
    Shawky::AuditLog.record!('crm_launch', account: account, user: user, auditable: conversation,
                                           metadata: { session_id: session_id, contact_id: contact.id, salesman: lead['salesman'] })
    conversation
  end

  private

  def allowed?(salesman)
    user == salesman || Shawky::ConversationAccess.for(user, account).administrator? || supervises?(salesman)
  end

  def supervises?(salesman)
    Shawky::TeamSupervisor.where(account: account, user: user).exists?(team_id: TeamMember.where(user_id: salesman.id).select(:team_id))
  end

  def contact_for(phone)
    contact = account.contacts.find_by(phone_number: phone) || account.contacts.new(phone_number: phone)
    contact.name = lead['name'] if lead['name'].present? && (contact.name.blank? || Shawky::PhoneMask.phone_like?(contact.name))
    contact.name ||= phone
    contact.custom_attributes = Shawky::Lead.merge_into(contact.custom_attributes, lead)
    contact.save!
    contact
  end

  def conversation_for(contact, salesman)
    inbox = Shawky::Routing.new(account).active_inbox
    existing = contact.conversations.where(inbox: inbox).where.not(status: :resolved).order(:created_at).last
    return hand_to(existing, salesman) if existing

    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    account.conversations.create!(inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: salesman)
  end

  def hand_to(conversation, salesman)
    previous_assignee_id = conversation.assignee_id
    return conversation if previous_assignee_id == salesman.id

    conversation.update!(assignee: salesman)
    if previous_assignee_id
      metadata = { from_user_id: previous_assignee_id, to_user_id: salesman.id, source: 'crm_launch' }
      Shawky::AuditLog.record!('conversation_reassigned', account: account, auditable: conversation, user: user, metadata: metadata)
    end
    conversation
  end
end
