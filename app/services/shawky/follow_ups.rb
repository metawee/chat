module Shawky::FollowUps
  module_function

  def agent_messages(account)
    account.messages.reorder(nil).where(message_type: :outgoing, sender_type: 'User', private: false)
  end

  # Workable open/pending conversations with no public agent message since cutoff.
  def for(user, account, cutoff)
    recent = agent_messages(account).where(created_at: cutoff..).select(:conversation_id)

    Shawky::ConversationAccess.for(user, account)
                              .filter_workable(account.conversations)
                              .where(status: %i[open pending])
                              .where(created_at: ...cutoff)
                              .where.not(id: recent)
                              .includes(:contact, :assignee)
                              .order(:created_at)
                              .limit(200)
  end
end
