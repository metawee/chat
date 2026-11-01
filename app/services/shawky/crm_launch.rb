# Opens the WhatsApp conversation for a lead claimed from the Shawky gateway (CRM "واتساب" button).
# The CRM only shows a lead to its salesman, so whoever clicked (the logged-in user) gets the
# conversation, even if it sat with someone else. Administrators and supervisors opening a
# lead that is already assigned leave it with its assignee.
class Shawky::CrmLaunch
  class InvalidLead < StandardError; end
  class NoWhatsappNumber < StandardError; end

  pattr_initialize [:account!, :user!, :lead!, :session_id]

  def perform
    raise NoWhatsappNumber unless Shawky::Routing.new(account).configured?

    phone = Shawky::PhoneNumber.e164(lead['phone'])
    raise InvalidLead if phone.blank?

    contact = contact_for(phone)
    conversation = conversation_for(contact)
    Shawky::AuditLog.record!('crm_launch', account: account, user: user, auditable: conversation,
                                           metadata: { session_id: session_id, contact_id: contact.id, salesman: lead['salesman'] })
    conversation
  end

  private

  def contact_for(phone)
    contact = account.contacts.find_by(phone_number: phone) || account.contacts.new(phone_number: phone)
    contact.name = lead['name'] if lead['name'].present? && (contact.name.blank? || Shawky::PhoneMask.phone_like?(contact.name))
    contact.name ||= phone
    contact.custom_attributes = Shawky::Lead.merge_into(contact.custom_attributes, lead)
    contact.save!
    contact
  end

  def conversation_for(contact)
    inbox = Shawky::Routing.new(account).active_inbox
    existing = contact.conversations.where(inbox: inbox).where.not(status: :resolved).order(:created_at).last
    return hand_over(existing) if existing

    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    account.conversations.create!(inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: user)
  end

  def hand_over(conversation)
    previous_assignee_id = conversation.assignee_id
    return conversation if previous_assignee_id == user.id || (previous_assignee_id && manager?)

    conversation.update!(assignee: user)
    if previous_assignee_id
      metadata = { from_user_id: previous_assignee_id, to_user_id: user.id, source: 'crm_launch' }
      Shawky::AuditLog.record!('conversation_reassigned', account: account, auditable: conversation, user: user, metadata: metadata)
    end
    conversation
  end

  def manager?
    access = Shawky::ConversationAccess.for(user, account)
    access.administrator? || access.supervisor?
  end
end
