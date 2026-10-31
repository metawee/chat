# Keeps the pricing Meta attaches to message status webhooks (ignored upstream) for the cost report.
module Shawky::Patches::WhatsappStatusPricing
  private

  def update_message_with_status(message, status)
    super
    Shawky::MessageCost.capture(message, status[:pricing]) if Shawky::Config.enabled?(:routing)
  end
end
