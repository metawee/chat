class Api::V1::Accounts::Shawky::DataExportsController < Api::V1::Accounts::Shawky::BaseController
  def index
    exports = ::Shawky::DataExport.where(account: Current.account).order(created_at: :desc).limit(50)
    render json: exports.map { |export| export_json(export) }
  end

  def create
    include_phone_numbers = ActiveModel::Type::Boolean.new.cast(params[:include_phone_numbers]) == true
    export = ::Shawky::DataExport.create!(
      account: Current.account, user: Current.user,
      from_date: params.require(:from_date), to_date: params.require(:to_date),
      file_format: params.require(:file_format), include_phone_numbers: include_phone_numbers
    )
    metadata = export.slice(:from_date, :to_date, :file_format, :include_phone_numbers).merge(type: 'conversations')
    ::Shawky::AuditLog.record!('export', account: Current.account, auditable: export, ip_address: request.remote_ip, metadata: metadata)
    ::Shawky::DataExportJob.perform_later(export)
    render json: export_json(export)
  end

  private

  def export_json(export)
    export.slice(:id, :from_date, :to_date, :file_format, :include_phone_numbers, :status).merge(
      created_at: export.created_at.to_i,
      download_url: export.file.attached? ? rails_blob_url(export.file, disposition: 'attachment') : nil
    )
  end
end
