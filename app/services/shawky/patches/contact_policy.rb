module Shawky::Patches::ContactPolicy
  def create?
    return super unless Shawky::ConversationAccess.enabled?

    Shawky::ConversationAccess.for(user, account).can_start_conversations?
  end
end
