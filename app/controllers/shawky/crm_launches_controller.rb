# GET /chat?code=... — target of the CRM "WhatsApp" button.
# The code is resolved with the CRM right away (it is single-use and valid for 60 seconds),
# the lead is parked server-side, and the browser continues to the dashboard with no code
# or lead data in the URL. Logging in, if needed, happens on the dashboard side.
# Plain ActionController::Base: this page needs no dashboard session or token auth.
class Shawky::CrmLaunchesController < ActionController::Base # rubocop:disable Rails/ApplicationController
  CODE_FORMAT = /\A[A-Za-z0-9_-]{16,256}\z/

  before_action :set_privacy_headers

  def show
    return render_error(:disabled, :not_found) unless Shawky::Config.enabled?(:crm)
    return render_error(:invalid_code, :bad_request) unless params[:code].to_s.match?(CODE_FORMAT)

    lead = Shawky::Crm::Client.new.resolve(params[:code])
    mapping = Shawky::CrmUserMapping.find_by(crm_user_id: lead.dig('agent', 'id'))
    return render_error(:unknown_agent, :forbidden) if mapping.nil?

    park(mapping.account, lead)
    redirect_to "/app/accounts/#{mapping.account_id}/shawky/crm-launch", status: :see_other
  rescue Shawky::Crm::Error => e
    render_crm_error(e)
  end

  private

  def park(account, lead)
    cookies.encrypted[Shawky::CrmLaunchStore::COOKIE] = {
      value: Shawky::CrmLaunchStore.put(account_id: account.id, lead: lead),
      expires: Shawky::CrmLaunchStore::TTL.from_now, httponly: true, secure: Rails.env.production?, same_site: :lax
    }
  end

  def render_crm_error(error)
    case error.status
    when 410 then render_error(:expired_code, :gone)
    when 429 then render_error(:rate_limited, :too_many_requests)
    else
      Rails.logger.error("[SHAWKY] CRM resolve failed: #{error.message}")
      render_error(:crm_unavailable, :bad_gateway)
    end
  end

  def render_error(reason, status)
    @message = I18n.t("shawky.crm_launch.errors.#{reason}", locale: :ar)
    render 'shawky/crm_launches/error', layout: false, status: status
  end

  def set_privacy_headers
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['Cache-Control'] = 'no-store'
  end
end
