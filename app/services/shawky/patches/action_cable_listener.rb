# Narrows realtime recipients to users allowed to see the conversation or contact.
# Upstream sends conversation events to every inbox member and contact events to the
# whole account stream.
module Shawky::Patches::ActionCableListener
  private

  def broadcast(account, tokens, event_name, data)
    return super unless Shawky::ConversationAccess.enabled?

    super(account, shawky_permitted_tokens(account, tokens, data), event_name, data)
  end

  def shawky_permitted_tokens(account, tokens, data)
    tokens = tokens.dup
    allowed_user_ids = if tokens.delete(account_token(account))
                         tokens += User.where(id: shawky_contact_viewer_ids(account, data)).pluck(:pubsub_token)
                         nil
                       else
                         conversation = shawky_conversation(account, data)
                         conversation && Shawky::ConversationAccess.viewer_ids(conversation)
                       end
    return tokens.uniq if allowed_user_ids.nil?

    blocked_tokens = User.where(pubsub_token: tokens).where.not(id: allowed_user_ids).pluck(:pubsub_token)
    tokens - blocked_tokens
  end

  def shawky_conversation(account, data)
    display_id = data[:conversation_id] || data.dig(:conversation, :id) || (data[:id] if data.key?(:meta))
    display_id && account.conversations.find_by(display_id: display_id)
  end

  def shawky_contact_viewer_ids(account, data)
    contact = data[:type] == 'contact' && account.contacts.find_by(id: data[:id])
    viewer_ids = account.administrators.pluck(:id)
    return viewer_ids unless contact

    viewer_ids + contact.conversations.flat_map { |conversation| Shawky::ConversationAccess.viewer_ids(conversation) }
  end
end
