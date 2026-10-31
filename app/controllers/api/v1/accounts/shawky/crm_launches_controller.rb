# Called by the dashboard launch page after login to finish a gateway launch.
class Api::V1::Accounts::Shawky::CrmLaunchesController < Api::V1::Accounts::BaseController
  def show
    token = cookies.encrypted[::Shawky::CrmLaunchStore::COOKIE]
    render json: { pending: ::Shawky::CrmLaunchStore.pending?(token) }
  end

  def create
    launch = ::Shawky::CrmLaunchStore.take(cookies.encrypted[::Shawky::CrmLaunchStore::COOKIE])
    cookies.delete(::Shawky::CrmLaunchStore::COOKIE)
    return render_error('expired', :gone) if launch.nil? || launch['account_id'] != Current.account.id

    conversation = ::Shawky::CrmLaunch.new(account: Current.account, user: Current.user, lead: launch['lead'],
                                           session_id: launch['session_id']).perform
    render json: { conversation_id: conversation.display_id, needs_template: !conversation.can_reply? }
  rescue ::Shawky::CrmLaunch::NotAllowed
    ::Shawky::AuditLog.record!('crm_launch_denied', account: Current.account, ip_address: request.remote_ip,
                                                    metadata: { session_id: launch['session_id'], salesman: launch.dig('lead', 'salesman') })
    render_error('not_allowed', :forbidden)
  rescue ::Shawky::CrmLaunch::InvalidLead
    render_error('invalid_lead', :unprocessable_entity)
  end

  private

  def render_error(code, status)
    render json: { error: code }, status: status
  end
end
