# Feature switches for Shawky customizations. All flags are on unless the env var is set to false.
module Shawky::Config
  FLAGS = {
    phone_masking: 'SHAWKY_PHONE_MASKING',
    access_control: 'SHAWKY_ACCESS_CONTROL',
    integrations_allowlist: 'SHAWKY_INTEGRATIONS_ALLOWLIST',
    routing: 'SHAWKY_ROUTING'
  }.freeze

  MASK_MODES = %w[last3 hidden].freeze

  def self.enabled?(flag)
    key = FLAGS.fetch(flag)
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(key, 'true'))
  end

  def self.mask_mode(account = Current.account)
    mode = account&.settings&.dig('shawky_phone_mask_mode')
    MASK_MODES.include?(mode) ? mode : 'last3'
  end

  def self.allowed_integrations
    ENV.fetch('SHAWKY_ALLOWED_INTEGRATIONS', 'webhook').split(',').map(&:strip)
  end

  def self.unmasked_webhook_hosts
    ENV.fetch('SHAWKY_UNMASKED_WEBHOOK_HOSTS', '').split(',').map(&:strip).compact_blank
  end

  def self.super_admin_allowed_ips
    ENV.fetch('SHAWKY_SUPER_ADMIN_ALLOWED_IPS', '').split(',').map(&:strip).compact_blank
  end
end
