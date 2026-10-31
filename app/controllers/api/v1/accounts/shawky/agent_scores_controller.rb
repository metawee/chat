# Weekly AI score per agent, for supervisors (their teams) and administrators (everyone).
class Api::V1::Accounts::Shawky::AgentScoresController < Api::V1::Accounts::BaseController
  PERIOD = 7.days

  def index
    access = ::Shawky::ConversationAccess.for(Current.user, Current.account)
    raise Pundit::NotAuthorizedError unless access.administrator? || access.supervisor?

    since = PERIOD.ago
    render json: { since: since.to_i, payload: ::Shawky::AgentScores.new(access: access, since: since).perform }
  end
end
