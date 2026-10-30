# When the WhatsApp 24-hour customer service window of a conversation closes (unix seconds),
# or nil when the window does not apply or no customer message exists yet.
module Shawky::MessageWindow
  module_function

  def closes_at(conversation)
    return unless conversation.inbox.channel_type == 'Channel::Whatsapp'

    last_incoming = conversation.messages.incoming.reorder(created_at: :desc).first
    last_incoming && (last_incoming.created_at + Conversations::MessageWindowService::MESSAGING_WINDOW_24_HOURS).to_i
  end
end
