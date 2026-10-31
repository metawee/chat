# Called by n8n, signed with SHAWKY_N8N_SECRET (see docs/shawky/N8N.md).
# Every body carries account_id and conversation_id (the display id shown in the dashboard).
class Shawky::Hooks::N8nController < ActionController::API
  before_action :verify_signature
  rescue_from KeyError, JSON::ParserError, TypeError, with: :render_invalid

  # After n8n looked the WhatsApp number up in the CRM (creating the lead if needed).
  # Body: { ..., lead: { lead_id, salesman, name, project, ... } }
  def crm_owner
    lead = payload.fetch('lead').to_h
    return render_invalid('lead.lead_id is required') if lead['lead_id'].blank?

    updated = Shawky::CrmOwnerAssignment.new(conversation: conversation, lead: lead).perform
    render json: { conversation_id: updated.display_id, assignee_id: updated.assignee_id }
  end

  # Body: { ..., ai_score: 0-100, ai_summary: "...", ai_flags: ["..."] }
  def ai_review
    score = payload.fetch('ai_score')
    summary = payload.fetch('ai_summary')
    flags = payload.fetch('ai_flags', [])
    return render_invalid('ai_score must be an integer from 0 to 100') unless score.is_a?(Integer) && score.between?(0, 100)
    return render_invalid('ai_summary must be a string') unless summary.is_a?(String)
    return render_invalid('ai_flags must be a list of strings') unless flags.is_a?(Array) && flags.all?(String)

    Shawky::AiReview.new(conversation: conversation, score: score, summary: summary, flags: flags).perform
    render json: { conversation_id: conversation.display_id }
  end

  # Body: { ..., reason: "..." }
  def abuse_alert
    reason = payload.fetch('reason')
    return render_invalid('reason is required') unless reason.is_a?(String) && reason.present?

    Shawky::AbuseAlert.new(conversation: conversation, reason: reason).perform
    render json: { conversation_id: conversation.display_id }
  end

  private

  def verify_signature
    valid = Shawky::Hmac.valid?(
      secret: ENV.fetch('SHAWKY_N8N_SECRET', nil), timestamp: request.headers['X-Shawky-Timestamp'],
      signature: request.headers['X-Shawky-Signature'], body: request.raw_post
    )
    head :unauthorized unless valid
  end

  def payload
    @payload ||= JSON.parse(request.raw_post)
  end

  def conversation
    @conversation ||= Account.find(payload.fetch('account_id')).conversations.find_by!(display_id: payload.fetch('conversation_id'))
  end

  def render_invalid(error)
    message = error.is_a?(Exception) ? error.message : error
    render json: { error: message }, status: :unprocessable_entity
  end
end
