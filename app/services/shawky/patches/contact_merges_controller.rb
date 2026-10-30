# Upstream lets any account user merge any two contacts, which would hand an agent
# someone else's customer. Merging is for administrators.
module Shawky::Patches::ContactMergesController
  def create
    raise Pundit::NotAuthorizedError if Shawky::ConversationAccess.enabled? &&
                                        !Shawky::ConversationAccess.for(Current.user, Current.account).administrator?

    super
  end
end
