module Shawky::Patches::SearchService
  private

  def filter_conversations
    return super if shawky_full_search?

    contacts = Shawky::Patches::ContactSearch.contacts(current_account.contacts, search_query)
    conversations_query = shawky_access.filter_workable(current_account.conversations)
    conversations_query = conversations_query.where(contact_id: contacts.select(:id))
                                             .or(conversations_query.where(display_id: search_query.to_i))
    if current_account.feature_enabled?('advanced_search')
      conversations_query = apply_time_filter(conversations_query, 'conversations.last_activity_at')
    end

    @conversations = conversations_query.order('conversations.created_at DESC').page(params[:page]).per(15)
  end

  def filter_contacts
    return super if shawky_full_search?

    contacts_query = Shawky::Patches::ContactSearch.contacts(shawky_access.filter_contacts(current_account.contacts), search_query)
    contacts_query = apply_time_filter(contacts_query, 'last_activity_at') if current_account.feature_enabled?('advanced_search')

    @contacts = contacts_query.resolved_contacts(
      use_crm_v2: current_account.feature_enabled?('crm_v2')
    ).order_on_last_activity_at('desc').page(params[:page]).per(15)
  end

  def message_base_query
    return super unless Shawky::ConversationAccess.enabled?

    super.where(conversation_id: shawky_access.filter_workable(current_account.conversations).select(:id))
  end

  def shawky_full_search?
    !Shawky::ConversationAccess.enabled? || shawky_access.can_search_by_phone?
  end

  def shawky_access
    @shawky_access ||= Shawky::ConversationAccess.for(current_user, current_account)
  end
end
