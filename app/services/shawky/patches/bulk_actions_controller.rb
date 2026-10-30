# Bulk assignment skips the per-conversation transfer rules, so it is for supervisors and admins.
module Shawky::Patches::BulkActionsController
  def create
    raise Pundit::NotAuthorizedError if Shawky::ConversationAccess.enabled? && shawky_assignment_change? && !shawky_can_bulk_assign?

    super
  end

  private

  def shawky_assignment_change?
    fields = params.fetch(:fields, {})
    fields.key?(:assignee_id) || fields.key?(:team_id)
  end

  def shawky_can_bulk_assign?
    access = Shawky::ConversationAccess.for(Current.user, Current.account)
    access.administrator? || access.supervisor?
  end
end
