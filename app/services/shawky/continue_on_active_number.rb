# Moves a customer to the active number (after a failover) without anyone typing the
# number: same contact, same assignee and team, new conversation in the active inbox.
class Shawky::ContinueOnActiveNumber
  pattr_initialize [:conversation!, :user!]

  def perform
    inbox = Shawky::Routing.new(conversation.account).active_inbox
    return conversation if inbox.id == conversation.inbox_id

    existing = conversation.contact.conversations.where(inbox: inbox).where.not(status: :resolved).last
    return existing if existing

    create_conversation(inbox)
  end

  private

  def create_conversation(inbox)
    contact_inbox = ContactInboxBuilder.new(contact: conversation.contact, inbox: inbox).perform
    new_conversation = conversation.account.conversations.create!(
      inbox: inbox, contact: conversation.contact, contact_inbox: contact_inbox,
      assignee: conversation.assignee || user, team: conversation.team
    )
    conversation.messages.create!(
      account: conversation.account, inbox: conversation.inbox, message_type: :activity,
      content: I18n.t('shawky.activities.continued_on_number', inbox_name: inbox.name)
    )
    new_conversation
  end
end
