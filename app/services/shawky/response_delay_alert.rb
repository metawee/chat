# Handles one conversation whose customer has waited longer than the reply delay:
# a private note mentioning the agent's supervisors (Chatwoot's mention notifications
# then reach them by web, mobile push and email) and, if enabled, a reassignment.
class Shawky::ResponseDelayAlert
  pattr_initialize [:conversation!, :routing!]

  def perform
    alert = Shawky::DelayAlert.create!(account: conversation.account, conversation: conversation,
                                       assignee: conversation.assignee, waiting_since: conversation.waiting_since)
    reassigned_to = reassign if routing.auto_reassign_on_delay?
    alert.update!(reassigned_to: reassigned_to) if reassigned_to
    post_note(alert.assignee, reassigned_to)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    nil # already alerted for this wait
  end

  private

  def supervisors
    users = Shawky::TeamSupervisor.users_for(conversation)
    users.exists? ? users : conversation.account.administrators
  end

  def reassign
    previous_assignee = conversation.assignee
    candidates = conversation.inbox.member_ids_with_assignment_capacity - [previous_assignee.id]
    new_assignee = AutoAssignment::AgentAssignmentService.new(conversation: conversation, allowed_agent_ids: candidates).find_assignee
    return if new_assignee.nil?

    conversation.update!(assignee: new_assignee)
    metadata = { from_user_id: previous_assignee.id, to_user_id: new_assignee.id, source: 'response_delay' }
    Shawky::AuditLog.record!('conversation_reassigned', account: conversation.account, auditable: conversation, user: nil, metadata: metadata)
    new_assignee
  end

  def post_note(agent, reassigned_to)
    I18n.with_locale(conversation.account.locale || I18n.default_locale) do
      mentions = Shawky::Mentions.markdown(supervisors)
      text = I18n.t('shawky.delay_alert.note', agent: agent.name, hours: hours_waiting)
      text += " #{I18n.t('shawky.delay_alert.reassigned', agent: reassigned_to.name)}" if reassigned_to
      conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing,
                                    private: true, content: "#{text} #{mentions}")
    end
  end

  def hours_waiting
    ((Time.current - conversation.waiting_since) / 1.hour).round(1)
  end
end
