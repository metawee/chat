# The contact's conversation history is readable (not writable) by whoever works the contact.
module Shawky::Patches::ContactConversationsController
  private

  def permitted_conversations
    return super unless Shawky::ConversationAccess.enabled?(Current.account)

    conversations = Current.account.conversations.includes(
      :assignee, :contact, :taggings, :contact_inbox
    ).preload(
      inbox: :channel,
      ai_assignee: { avatar_attachment: [:blob] }
    ).where(contact_id: @contact.id)

    Shawky::ConversationAccess.for(Current.user, Current.account).filter_readable(conversations)
  end
end
