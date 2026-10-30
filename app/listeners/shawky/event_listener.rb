class Shawky::EventListener < BaseListener
  # A brand-new customer's first message gets the welcome text as a free-form reply:
  # it sits inside the window the customer just opened, so it is billed as a service
  # message rather than a marketing template.
  def message_created(event)
    message = event.data[:message]
    return unless Shawky::Config.enabled?(:routing) && message.incoming?

    conversation = message.conversation
    routing = Shawky::Routing.new(conversation.account)
    return unless routing.managed_inbox?(conversation.inbox) && routing.welcome_message
    return unless conversation.contact.conversations.one? && conversation.messages.incoming.one?

    send_welcome(conversation, routing.welcome_message)
  end

  def message_updated(event)
    message = event.data[:message]
    return unless Shawky::Config.enabled?(:routing) && message.failed?

    code = message.external_error.to_s[/\A(\d+):/, 1]
    return unless Shawky::Routing::FAILOVER_ERROR_CODES.include?(code)

    routing = Shawky::Routing.new(message.account)
    return unless routing.primary_inbox_id == message.inbox_id

    routing.failover!(reason: "send_error #{code}", details: { code: code, message_id: message.id })
  end

  private

  def send_welcome(conversation, content)
    conversation.reload.with_lock do
      next if conversation.custom_attributes['shawky_welcome_sent']

      conversation.update!(custom_attributes: conversation.custom_attributes.merge('shawky_welcome_sent' => true))
      conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing, content: content)
    end
  end
end
