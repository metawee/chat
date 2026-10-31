module Shawky::Patches::PermissionFilterService
  def perform
    return super unless Shawky::ConversationAccess.enabled?(account) && user.is_a?(User)

    Shawky::ConversationAccess.for(user, account).filter_workable(conversations)
  end
end
