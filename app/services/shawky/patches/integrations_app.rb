# Integrations push conversation data to third parties, so only allowlisted ones can be used.
module Shawky::Patches::IntegrationsApp
  def active?(account)
    return super unless Shawky::Config.enabled?(:integrations_allowlist)

    Shawky::Config.allowed_integrations.include?(id) && super
  end
end
