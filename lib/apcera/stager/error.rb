module Apcera
  module Error
    class StagerURLRequired < StandardError; end
    class ExecuteError < StandardError; end
    class AppPathError < StandardError; end
  end
end
