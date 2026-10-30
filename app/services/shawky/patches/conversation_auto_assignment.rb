module Shawky::Patches::ConversationAutoAssignment
  private

  def run_auto_assignment
    return super unless Shawky::Config.enabled?(:routing) && saved_change_to_id? && assignee_id.blank?
    return super unless inbox.enable_auto_assignment? && Shawky::Routing.new(account).managed_inbox?(inbox)

    Shawky::ConversationRouter.new(conversation: self).route
  end
end
