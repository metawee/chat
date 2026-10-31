class Api::V1::Accounts::Shawky::CostReportsController < Api::V1::Accounts::Shawky::BaseController
  def show
    from = Date.iso8601(params.require(:from)).in_time_zone.beginning_of_day
    to = Date.iso8601(params.require(:to)).in_time_zone.end_of_day
    render json: ::Shawky::CostReport.new(account: Current.account, from: from, to: to).perform
  rescue Date::Error
    render json: { error: 'from and to must be YYYY-MM-DD' }, status: :unprocessable_entity
  end
end
