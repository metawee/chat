module Shawky::Patches::WebhookTrigger
  private

  def perform_request
    @payload = Shawky::PayloadMasker.call(@payload) if Shawky::Config.enabled?(:phone_masking)
    super
  end
end
