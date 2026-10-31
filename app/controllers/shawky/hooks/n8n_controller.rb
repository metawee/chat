# Called by n8n after it looked the WhatsApp number up in the CRM (creating the lead if needed).
# Body: { account_id, conversation_id (display id), lead: { lead_id, salesman, name, project, ... } }
class Shawky::Hooks::N8nController < ActionController::API
  before_action :verify_signature

  def crm_owner
    account = Account.find(payload.fetch('account_id'))
    conversation = account.conversations.find_by!(display_id: payload.fetch('conversation_id'))
    lead = payload.fetch('lead').to_h
    return render json: { error: 'lead.lead_id is required' }, status: :unprocessable_entity if lead['lead_id'].blank?

    conversation = Shawky::CrmOwnerAssignment.new(conversation: conversation, lead: lead).perform
    render json: { conversation_id: conversation.display_id, assignee_id: conversation.assignee_id }
  rescue KeyError, JSON::ParserError, TypeError => e
    render json: { error: e.message }, status: :unprocessable_entity
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
end
