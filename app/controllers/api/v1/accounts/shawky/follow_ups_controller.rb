# R5: open/pending conversations the user works on where no agent has written for
# the configured number of days (default 3).
class Api::V1::Accounts::Shawky::FollowUpsController < Api::V1::Accounts::BaseController
  def index
    cutoff = ::Shawky::Routing.new(Current.account).follow_up_after.ago
    conversations = ::Shawky::FollowUps.for(Current.user, Current.account, cutoff).to_a
    last_agent_message_at = ::Shawky::FollowUps.agent_messages(Current.account)
                                               .where(conversation_id: conversations.map(&:id))
                                               .group(:conversation_id).maximum(:created_at)

    render json: { payload: conversations.map { |conversation| follow_up_json(conversation, last_agent_message_at[conversation.id]) } }
  end

  private

  def follow_up_json(conversation, last_agent_message_at)
    {
      id: conversation.display_id, status: conversation.status, inbox_id: conversation.inbox_id,
      contact_name: conversation.contact.name, lead_id: conversation.contact.custom_attributes['lead_id'],
      assignee: conversation.assignee&.slice(:id, :name), last_agent_message_at: last_agent_message_at&.to_i,
      created_at: conversation.created_at.to_i
    }
  end
end
