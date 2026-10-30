class Api::V1::Accounts::Shawky::SettingsController < Api::V1::Accounts::Shawky::BaseController
  # request param => account.settings key
  SETTING_KEYS = {
    phone_mask_mode: 'shawky_phone_mask_mode', primary_inbox_id: 'shawky_primary_inbox_id', backup_inbox_id: 'shawky_backup_inbox_id',
    welcome_message: 'shawky_welcome_message', crm_owner_wait_seconds: 'shawky_crm_owner_wait_seconds'
  }.freeze
  INTEGER_SETTINGS = %i[primary_inbox_id backup_inbox_id crm_owner_wait_seconds].freeze

  before_action :validate_settings, only: [:update]

  def show
    routing = ::Shawky::Routing.new(Current.account)
    render json: {
      phone_mask_mode: ::Shawky::Config.mask_mode(Current.account),
      primary_inbox_id: routing.primary_inbox_id, backup_inbox_id: routing.backup_inbox_id,
      active_inbox_id: routing.configured? ? routing.active_inbox_id : nil,
      welcome_message: routing.welcome_message, crm_owner_wait_seconds: routing.crm_owner_wait.to_i
    }
  end

  def update
    ::Shawky::Routing.new(Current.account).update_settings(setting_changes)
    # Shawky routing hooks into the legacy round robin; Assignment V2 would race it for new conversations.
    Current.account.disable_features!('assignment_v2') if params[:primary_inbox_id].present?
    show
  end

  def failback
    ::Shawky::Routing.new(Current.account).failback!(user: Current.user)
    show
  end

  private

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

      changes[setting] = INTEGER_SETTINGS.include?(param) ? params[param].to_i : params[param].to_s
    end
  end

  def render_invalid(key)
    render json: { error: "invalid #{key}" }, status: :unprocessable_entity
  end
end
