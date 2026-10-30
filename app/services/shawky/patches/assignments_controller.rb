module Shawky::Patches::AssignmentsController
  def create
    return super unless Shawky::ConversationAccess.enabled?

    access = Shawky::ConversationAccess.for(Current.user, Current.account)
    raise Pundit::NotAuthorizedError unless shawky_assignment_allowed?(access)

    previous_assignee_id = @conversation.assignee_id
    super
    shawky_audit_reassignment(previous_assignee_id)
  end

  private

  def shawky_assignment_allowed?(access)
    return true if access.administrator? || access.supervisor?
    # Agents may only hand a conversation to a teammate.
    return false if agent_bot_assignment? || !params.key?(:assignee_id)

    access.can_assign_to?(Current.account.users.find_by(id: params[:assignee_id]))
  end

  def shawky_audit_reassignment(previous_assignee_id)
    current_assignee_id = @conversation.reload.assignee_id
    return if current_assignee_id == previous_assignee_id

    Shawky::AuditLog.record!(
      'conversation_reassigned',
      account: Current.account,
      auditable: @conversation,
      ip_address: request.remote_ip,
      metadata: { from_user_id: previous_assignee_id, to_user_id: current_assignee_id, source: 'manual' }
    )
  end
end
