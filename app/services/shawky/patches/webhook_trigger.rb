# Webhook payloads are masked, except signed account webhooks to an allowlisted HTTPS
# host (our n8n), which need the full number to match CRM leads. Automation and macro
# webhooks are unsigned and stay masked.
module Shawky::Patches::WebhookTrigger
  private

  def perform_request
    @payload = Shawky::PayloadMasker.call(@payload) if Shawky::Config.enabled?(:phone_masking) && !shawky_trusted_target?
    super
  end

  def shawky_trusted_target?
    uri = URI.parse(@url)
    @webhook_type == :account_webhook && @secret.present? && uri.scheme == 'https' &&
      Shawky::Config.unmasked_webhook_hosts.include?(uri.host)
  rescue URI::InvalidURIError
    false
  end
end
