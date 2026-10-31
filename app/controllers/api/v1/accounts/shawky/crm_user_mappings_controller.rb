class Api::V1::Accounts::Shawky::CrmUserMappingsController < Api::V1::Accounts::Shawky::BaseController
  def index
    render json: ::Shawky::CrmUserMapping.where(account: Current.account).as_json(only: [:id, :crm_username, :user_id])
  end

  def create
    mapping = ::Shawky::CrmUserMapping.create!(
      account: Current.account, crm_username: params.require(:crm_username).to_s.strip, user_id: params.require(:user_id)
    )
    render json: mapping.as_json(only: [:id, :crm_username, :user_id])
  end

  def destroy
    ::Shawky::CrmUserMapping.where(account: Current.account).find(params[:id]).destroy!
    head :ok
  end
end
