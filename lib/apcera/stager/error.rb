module Apcera
  module Error
    class StagerURLRequired < StandardError; end
    class PackageDownloadError < StandardError; end
    class ExecuteError < StandardError; end
    class PackageMetadataError < StandardError; end
  end
end
