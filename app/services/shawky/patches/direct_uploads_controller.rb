# Upstream does not authorize direct uploads against the conversation at all.
module Shawky::Patches::DirectUploadsController
  private

  def conversation
    super
    return @conversation unless Shawky::ConversationAccess.enabled?(Current.account) && @conversation

    @conversation = nil unless Shawky::ConversationAccess.for(Current.user, Current.account).writable?(@conversation)
    @conversation
  end
end
