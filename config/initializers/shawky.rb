# Shawky Group customizations (see docs/shawky/PLAN.md).

# Restricts /super_admin and the Sidekiq dashboard (job arguments carry raw WhatsApp
# payloads) to CWS IPs. SHAWKY_DISABLE_SIDEKIQ_WEB=true hides Sidekiq entirely.
class ShawkyAdminIpAllowlist
  PROTECTED_PREFIXES = %w[/super_admin /monitoring].freeze
  SIDEKIQ_PREFIX = '/monitoring/sidekiq'.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    return not_found if blocked?(request)

    @app.call(env)
  end

  private

  def blocked?(request)
    path = request.path
    return false unless PROTECTED_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    return true if path.start_with?(SIDEKIQ_PREFIX) && ActiveModel::Type::Boolean.new.cast(ENV.fetch('SHAWKY_DISABLE_SIDEKIQ_WEB', false))

    allowed_ips = Shawky::Config.super_admin_allowed_ips
    allowed_ips.present? && allowed_ips.exclude?(request.remote_ip)
  end

  def not_found
    [404, { 'Content-Type' => 'text/plain' }, ['Not Found']]
  end
end

Rails.application.config.middleware.use ShawkyAdminIpAllowlist

Rack::Attack.throttle('shawky/hooks/ip', limit: 120, period: 1.minute) do |request|
  request.ip if request.path.start_with?('/shawky/')
end

Rack::Attack.throttle('shawky/phone_reveal/ip', limit: 20, period: 1.minute) do |request|
  request.ip if request.path.match?(%r{/shawky/contacts/\d+/phone\z})
end

Rack::Attack.throttle('shawky/chat/ip', limit: 30, period: 1.minute) do |request|
  request.ip if request.path == '/chat'
end

# R7: attachment links (/rails/active_storage/...) stop working after this many hours, so a
# copied link to a customer's photo or voice note does not stay valid forever. Off in the
# test environment, where upstream specs compare generated URLs; Shawky's spec turns it on.
attachment_url_ttl_hours = ENV.fetch('SHAWKY_ATTACHMENT_URL_TTL_HOURS', Rails.env.test? ? '0' : '24').to_i
Rails.application.config.active_storage.urls_expire_in = attachment_url_ttl_hours.hours if attachment_url_ttl_hours.positive?
