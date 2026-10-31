module Shawky::Patches::ContactsBaseController
  private

  def ensure_contact
    super
    return unless Shawky::ConversationAccess.enabled?(Current.account)

    access = Shawky::ConversationAccess.for(Current.user, Current.account)
    raise ActiveRecord::RecordNotFound unless access.filter_contacts(Current.account.contacts).exists?(id: @contact.id)
  end
end
