# Webhook payloads are masked, except signed account webhooks to an allowlisted HTTPS
# host (our n8n), which need the full number to match CRM leads. Automation and macro
# webhooks are unsigned and stay masked.
module Shawky::Patches::WebhookTrigger
  private

  def perform_request
    @payload = Shawky::PayloadMasker.call(@payload) if Shawky::PhoneMask.enabled?(shawky_account) && !shawky_trusted_target?
    super
  end

  # Conversation, message and contact webhook payloads carry account: { id, name }.
  def shawky_account
    account_id = @payload.dig(:account, :id) || @payload.dig('account', 'id') || @payload[:account_id]
    account_id && Account.find_by(id: account_id)
  end

  def shawky_trusted_target?
    uri = URI.parse(@url)
    @webhook_type == :account_webhook && @secret.present? && uri.scheme == 'https' &&
      Shawky::Config.unmasked_webhook_hosts.include?(uri.host)
  rescue URI::InvalidURIError
    false
  end
end
