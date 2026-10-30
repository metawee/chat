module Shawky::Patches::IntegrationsHook
  def self.prepended(base)
    base.validate :shawky_integration_allowed, on: :create
  end

  private

  def shawky_integration_allowed
    return unless Shawky::Config.enabled?(:integrations_allowlist)

    errors.add(:app_id, :inclusion) unless Shawky::Config.allowed_integrations.include?(app_id)
  end
end
