class Api::V1::Accounts::Shawky::SettingsController < Api::V1::Accounts::Shawky::BaseController
  # request param => account.settings key
  SETTING_KEYS = {
    phone_mask_mode: 'shawky_phone_mask_mode', primary_inbox_id: 'shawky_primary_inbox_id', backup_inbox_id: 'shawky_backup_inbox_id',
    welcome_message: 'shawky_welcome_message', crm_owner_wait_seconds: 'shawky_crm_owner_wait_seconds',
    reply_delay_minutes: 'shawky_reply_delay_minutes', auto_reassign_on_delay: 'shawky_auto_reassign_on_delay',
    follow_up_days: 'shawky_follow_up_days', message_rates: 'shawky_message_rates',
    phone_masking_enabled: 'shawky_phone_masking_enabled', restricted_visibility_enabled: 'shawky_restricted_visibility_enabled',
    gateway_launch_enabled: 'shawky_gateway_launch_enabled'
  }.freeze
  INTEGER_SETTINGS = %i[primary_inbox_id backup_inbox_id crm_owner_wait_seconds reply_delay_minutes follow_up_days].freeze
  BOOLEAN_SETTINGS = %i[auto_reassign_on_delay phone_masking_enabled restricted_visibility_enabled gateway_launch_enabled].freeze

  before_action :validate_settings, only: [:update]

  def show
    routing = ::Shawky::Routing.new(Current.account)
    render json: {
      phone_mask_mode: ::Shawky::Config.mask_mode(Current.account),
      primary_inbox_id: routing.primary_inbox_id, backup_inbox_id: routing.backup_inbox_id,
      active_inbox_id: routing.configured? ? routing.active_inbox_id : nil,
      welcome_message: routing.welcome_message, crm_owner_wait_seconds: routing.crm_owner_wait.to_i,
      reply_delay_minutes: routing.reply_delay.in_minutes.to_i, auto_reassign_on_delay: routing.auto_reassign_on_delay?,
      follow_up_days: routing.follow_up_after.in_days.to_i, message_rates: Current.account.settings&.dig('shawky_message_rates') || {},
      **switch_states
    }
  end

  def update
    ::Shawky::Settings.update!(Current.account, setting_changes, user: Current.user, ip_address: request.remote_ip)
    # Shawky routing hooks into the legacy round robin; Assignment V2 would race it for new conversations.
    Current.account.disable_features!('assignment_v2') if params[:primary_inbox_id].present?
    show
  end

  def gateway_health
    ::Shawky::Gateway::Client.new.health
    render json: { ok: true }
  rescue ::Shawky::Gateway::Error, KeyError => e
    render json: { ok: false, status: e.try(:status) }
  end

  def failback
    ::Shawky::Routing.new(Current.account).failback!(user: Current.user)
    show
  end

  private

  def switch_states
    states = ::Shawky::Settings::SWITCHES.keys.to_h { |switch| [:"#{switch}_enabled", ::Shawky::Settings.enabled?(Current.account, switch)] }
    states.merge(gateway_configured: ENV['SHAWKY_GATEWAY_URL'].present? && ENV['SHAWKY_GATEWAY_API_KEY'].present?)
  end

  def validate_settings
    return render_invalid(:phone_mask_mode) if params.key?(:phone_mask_mode) && ::Shawky::Config::MASK_MODES.exclude?(params[:phone_mask_mode])

    whatsapp_inboxes = Current.account.inboxes.where(channel_type: 'Channel::Whatsapp')
    %i[primary_inbox_id backup_inbox_id].each do |key|
      return render_invalid(key) if params[key].present? && !whatsapp_inboxes.exists?(id: params[key])
    end
  end

  def setting_changes
    SETTING_KEYS.each_with_object({}) do |(param, setting), changes|
      next unless params.key?(param)

      changes[setting] = cast_setting(param, params[param])
    end
  end

  def cast_setting(param, value)
    return value.to_i if INTEGER_SETTINGS.include?(param)
    return ActiveModel::Type::Boolean.new.cast(value) == true if BOOLEAN_SETTINGS.include?(param)
    return message_rates(value) if param == :message_rates

    value.to_s
  end

  # { "SA" => { "marketing" => 0.0455 }, "default" => { ... } } with numeric rates only.
  def message_rates(value)
    value.to_unsafe_h.to_h do |country, categories|
      key = country.to_s == 'default' ? 'default' : country.to_s.upcase
      [key, categories.to_h.slice(*::Shawky::CostReport::CATEGORIES).transform_values(&:to_f)]
    end
  end

  def render_invalid(key)
    render json: { error: "invalid #{key}" }, status: :unprocessable_entity
  end
end
