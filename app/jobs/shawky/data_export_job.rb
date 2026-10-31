class Shawky::DataExportJob < ApplicationJob
  queue_as :low

  def perform(export)
    Tempfile.create(['shawky-export', ".#{export.file_format}"]) do |file|
      Shawky::DataExportBuilder.new(export: export).write(file)
      file.rewind
      filename = "shawky-#{export.from_date}-#{export.to_date}.#{export.file_format}"
      export.file.attach(io: file, filename: filename, content_type: export.file_format == 'csv' ? 'text/csv' : 'application/json')
    end
    export.completed!
  rescue StandardError
    export.failed!
    raise
  end
end
