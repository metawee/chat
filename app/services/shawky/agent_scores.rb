# Weekly agent quality board: average n8n AI score per assignee over the conversations
# reviewed since `since`, limited to the conversations the viewer may work on.
class Shawky::AgentScores
  pattr_initialize [:access!, :since!]

  def perform
    reviewed = access.workable_conversations.where.not(assignee_id: nil).where(updated_at: since..)
                     .includes(:assignee).select { |conversation| reviewed_since?(conversation) }

    reviewed.group_by(&:assignee).map { |assignee, conversations| row(assignee, conversations) }
            .sort_by { |row| -row[:average_score] }
  end

  private

  def reviewed_since?(conversation)
    reviewed_at = conversation.custom_attributes['ai_reviewed_at']
    conversation.custom_attributes['ai_score'].is_a?(Integer) && reviewed_at.present? && Time.zone.parse(reviewed_at) >= since
  end

  def row(assignee, conversations)
    scores = conversations.map { |conversation| conversation.custom_attributes['ai_score'] }
    {
      user_id: assignee.id, name: assignee.name, reviewed_count: conversations.size,
      average_score: (scores.sum.to_f / scores.size).round(1),
      flagged_count: conversations.count { |conversation| conversation.custom_attributes['ai_flags'].present? },
      abuse_count: conversations.count { |conversation| conversation.cached_label_list_array.include?(Shawky::AbuseAlert::LABEL) }
    }
  end
end
