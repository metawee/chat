module Shawky::Patches::ContactsController
  IDENTITY_FIELDS = %i[phone_number identifier email].freeze
  PHONE_SORTS = %w[phone_number -phone_number].freeze

  def self.prepended(base)
    base.before_action :shawky_drop_phone_sort, only: [:index, :active, :search, :filter]
  end

  def search
    return super if !shawky_enabled? || shawky_access.can_search_by_phone? || params[:q].blank?

    @contacts = fetch_contacts_with_has_more(Shawky::Patches::ContactSearch.contacts(Current.account.contacts, params[:q].strip))
    render :search
  end

  private

  def fetch_contacts(contacts)
    super(shawky_scope(contacts))
  end

  def fetch_contacts_with_has_more(contacts)
    super(shawky_scope(contacts))
  end

  def fetch_contact
    super
    raise ActiveRecord::RecordNotFound unless shawky_scope(Current.account.contacts).exists?(id: @contact.id)
  end

  def permitted_params
    return super unless shawky_enabled? && action_name == 'update' && !shawky_access.can_edit_contact_identity?

    super.except(*IDENTITY_FIELDS)
  end

  def shawky_drop_phone_sort
    params.delete(:sort) if shawky_enabled? && !shawky_access.can_search_by_phone? && PHONE_SORTS.include?(params[:sort])
  end

  def shawky_scope(contacts)
    return contacts unless shawky_enabled?

    shawky_access.filter_contacts(contacts)
  end

  def shawky_enabled?
    Shawky::ConversationAccess.enabled?
  end

  def shawky_access
    @shawky_access ||= Shawky::ConversationAccess.for(Current.user, Current.account)
  end
end
