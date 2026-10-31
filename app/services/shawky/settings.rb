# Account-level Shawky switches, stored in accounts.settings so administrators change them from
# Settings → Shawky without a deploy. Every change is written to shawky_audit_logs.
# The matching env flags (Shawky::Config) stay as installation-wide kill switches.
module Shawky::Settings
  SWITCHES = {
    phone_masking: { key: 'shawky_phone_masking_enabled', default: false },
    restricted_visibility: { key: 'shawky_restricted_visibility_enabled', default: true },
    gateway_launch: { key: 'shawky_gateway_launch_enabled', default: true }
  }.freeze

  module_function

  def enabled?(account, switch)
    return false if account.nil?

    cache = (Shawky::RequestCache.settings ||= {})
    cache[[account.id, switch]] ||= begin
      config = SWITCHES.fetch(switch)
      value = account.settings&.fetch(config[:key], nil)
      [value.nil? ? config[:default] : value == true]
    end
    cache[[account.id, switch]].first
  end

  # changes: { 'shawky_some_key' => new_value }; audits each value that actually changes.
  def update!(account, changes, user:, ip_address: nil)
    previous = account.settings || {}
    changed = changes.reject { |key, value| previous[key] == value }
    return if changed.empty?

    account.update!(settings: previous.merge(changed))
    Shawky::RequestCache.settings = nil
    changed.each do |key, value|
      Shawky::AuditLog.record!('settings_changed', account: account, user: user, ip_address: ip_address,
                                                   metadata: { key: key, old: previous[key], new: value })
    end
  end
end
