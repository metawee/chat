module Shawky::Patches::ContactsExportJob
  def perform(account_id, user_id, column_names, params)
    super
    Shawky::AuditLog.record!(
      'export', account: Account.find(account_id), user: User.find_by(id: user_id),
                metadata: { type: 'contacts', columns: column_names }
    )
  end

  private

  def value_for_header(contact, header)
    value = super
    return value unless Shawky::Config.enabled?(:phone_masking)

    header == 'name' ? Shawky::PhoneMask.mask_embedded(value) : Shawky::PayloadMasker.call(value)
  end
end
