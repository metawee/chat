module Shawky::Patches::ContactsFilterService
  IDENTITY_ATTRIBUTES = %w[phone_number identifier].freeze

  def perform
    return super unless Shawky::ConversationAccess.enabled?(@account)

    raise Pundit::NotAuthorizedError if shawky_identity_filter? && !shawky_access.can_search_by_phone?

    super
  end

  def base_relation
    return super unless Shawky::ConversationAccess.enabled?(@account)

    shawky_access.filter_contacts(super)
  end

  private

  def shawky_identity_filter?
    Array(@params[:payload]).any? { |query_hash| IDENTITY_ATTRIBUTES.include?((query_hash[:attribute_key] || query_hash['attribute_key']).to_s) }
  end

  def shawky_access
    @shawky_access ||= Shawky::ConversationAccess.for(@user, @account)
  end
end
