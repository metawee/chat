module Shawky::Patches::ConversationsController
  private

  # contact_inbox is the first create callback that writes (it builds the contact inbox),
  # so the check runs here, after authentication and inside the exception handler.
  def contact_inbox
    raise Pundit::NotAuthorizedError if Shawky::ConversationAccess.enabled?(Current.account) &&
                                        !Shawky::ConversationAccess.for(Current.user, Current.account).can_start_conversations?

    super
  end
end
