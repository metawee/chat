class Api::V1::Accounts::Shawky::BaseController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
end
