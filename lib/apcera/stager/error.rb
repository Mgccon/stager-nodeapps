module Apcera
  module Error
    class DownloadError < StandardError; end
    class StagerURLRequired < StandardError; end
    class ExecuteError < StandardError; end
    class AppPathError < StandardError; end
  end
end
