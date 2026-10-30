module Shawky::Patches::ContactInboxesController
  def create
    raise Pundit::NotAuthorizedError if Shawky::ConversationAccess.enabled? &&
                                        !Shawky::ConversationAccess.for(Current.user, Current.account).can_start_conversations?

    super
  end
end
