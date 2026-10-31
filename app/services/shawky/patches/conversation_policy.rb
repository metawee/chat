module Shawky::Patches::ConversationPolicy
  def show?
    return super unless shawky_applies?

    shawky_access.readable?(record)
  end

  # Replying, assigning, resolving, labelling... History conversations are read-only.
  def shawky_write?
    return show? unless shawky_applies?

    shawky_access.writable?(record)
  end

  private

  def shawky_applies?
    Shawky::ConversationAccess.enabled?(account) && user.is_a?(User)
  end

  def shawky_access
    @shawky_access ||= Shawky::ConversationAccess.for(user, account)
  end
end
