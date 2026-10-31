# Readable by every user: the dashboard needs it to offer "continue on active number".
class Api::V1::Accounts::Shawky::RoutingController < Api::V1::Accounts::BaseController
  def show
    routing = ::Shawky::Routing.new(Current.account)
    access = ::Shawky::ConversationAccess.for(Current.user, Current.account)
    render json: {
      primary_inbox_id: routing.primary_inbox_id, backup_inbox_id: routing.backup_inbox_id,
      active_inbox_id: routing.configured? ? routing.active_inbox_id : nil,
      phone_masking_enabled: ::Shawky::PhoneMask.enabled?(Current.account),
      can_view_agent_scores: access.administrator? || access.supervisor?
    }
  end
end
