# The one place a full customer number leaves the server: an administrator asks for it
# explicitly and the request is audited.
class Api::V1::Accounts::Shawky::ContactPhonesController < Api::V1::Accounts::Shawky::BaseController
  skip_after_action :shawky_mask_response

  def show
    contact = Current.account.contacts.find(params[:contact_id])
    ::Shawky::AuditLog.record!('phone_revealed', account: Current.account, auditable: contact, ip_address: request.remote_ip)

    render json: { id: contact.id, phone_number: contact.phone_number }
  end
end
