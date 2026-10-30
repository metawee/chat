class Api::V1::Accounts::Shawky::SettingsController < Api::V1::Accounts::Shawky::BaseController
  def show
    render json: { phone_mask_mode: ::Shawky::Config.mask_mode(Current.account) }
  end

  def update
    mode = params.require(:phone_mask_mode)
    return render json: { error: 'invalid phone_mask_mode' }, status: :unprocessable_entity unless ::Shawky::Config::MASK_MODES.include?(mode)

    Current.account.update!(settings: Current.account.settings.merge('shawky_phone_mask_mode' => mode))
    show
  end
end
