# GET /shawky/launch?session=s_... — opened by the gateway (or the desktop app) after a CRM
# "واتساب" button. The one-time session is claimed from the gateway at once (it lives 120
# seconds), the lead is parked server-side behind an encrypted cookie, and the browser moves on
# with no session id or lead data in the URL. Logging in, if needed, happens on the dashboard side.
# Plain ActionController::Base: this page needs no dashboard session or token auth.
class Shawky::LaunchesController < ActionController::Base # rubocop:disable Rails/ApplicationController
  SESSION_FORMAT = /\As_[A-Za-z0-9_-]{8,128}\z/

  before_action :set_privacy_headers

  def show
    return render_error(:disabled, :not_found) unless Shawky::Config.enabled?(:gateway_launch)
    return render_error(:invalid_session, :bad_request) unless params[:session].to_s.match?(SESSION_FORMAT)

    lead = Shawky::Gateway::Client.new.claim_session(params[:session]).fetch('lead')
    mapping = salesman_mapping(lead)
    return render_error(:unknown_salesman, :forbidden) if mapping.nil?
    return render_error(:disabled, :not_found) unless Shawky::Settings.enabled?(mapping.account, :gateway_launch)

    park(mapping.account, lead)
    redirect_to "/app/accounts/#{mapping.account_id}/shawky/crm-launch", status: :see_other
  rescue Shawky::Gateway::Error => e
    render_gateway_error(e)
  end

  private

  def salesman_mapping(lead)
    Shawky::CrmUserMapping.find_by(crm_username: lead['salesman'].to_s.strip)
  end

  def park(account, lead)
    cookies.encrypted[Shawky::CrmLaunchStore::COOKIE] = {
      value: Shawky::CrmLaunchStore.put(account_id: account.id, lead: lead, session_id: params[:session]),
      expires: Shawky::CrmLaunchStore::TTL.from_now, httponly: true, secure: Rails.env.production?, same_site: :lax
    }
  end

  def render_gateway_error(error)
    return render_error(:expired_session, :gone) if error.status == 410

    Rails.logger.error("[SHAWKY] gateway session claim failed: #{error.message}")
    render_error(:gateway_unavailable, :bad_gateway)
  end

  def render_error(reason, status)
    @message = I18n.t("shawky.crm_launch.errors.#{reason}", locale: :ar)
    render 'shawky/launches/error', layout: false, status: status
  end

  def set_privacy_headers
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['Cache-Control'] = 'no-store'
  end
end
