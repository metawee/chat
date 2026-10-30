class Api::V1::Accounts::Shawky::TeamSupervisorsController < Api::V1::Accounts::Shawky::BaseController
  def index
    render json: ::Shawky::TeamSupervisor.where(account: Current.account).as_json(only: [:id, :team_id, :user_id])
  end

  def create
    supervisor = ::Shawky::TeamSupervisor.create!(team: Current.account.teams.find(params[:team_id]), user_id: params[:user_id])
    render json: supervisor.as_json(only: [:id, :team_id, :user_id])
  end

  def destroy
    ::Shawky::TeamSupervisor.where(account: Current.account).find(params[:id]).destroy!
    head :ok
  end
end
