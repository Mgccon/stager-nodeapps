module Apcera
  class Stager
    attr_accessor :stager_url, :app_path, :root_path, :pkg_path, :updated_pkg_path, :system_options

    PKG_NAME = "pkg.tar.gz"
    UPDATED_PKG_NAME = "updated.tar.gz"

    def initialize(options = {})
      # Require stager url. Needed to talk to the Staging Coordinator.
      @stager_url = options[:stager_url] || ENV["STAGER_URL"]
      raise Apcera::Error::StagerURLRequired.new("stager_url required") unless @stager_url

      # Setup the environment, some test items here.
      setup_environment
    end

    # Download a package from the staging coordinator.
    def download
      response = RestClient.get(@stager_url + "/data")
      File.open(@pkg_path, "wb") do |f|
        f.write(response.to_str)
      end
    rescue => e
      fail e
    end

    # Execute a command in the shell.
    # We don't want real commands in tests.
    def execute(cmd)
      Bundler.with_clean_env do
        result = system(cmd, @system_options)
        if !result
          raise Apcera::Error::ExecuteError.new("failed to execute: #{cmd}.\n")
        end

        result
      end
    rescue => e
      fail e
    end

    # Execute a command in the app dir. Useful helper.
    def execute_app(cmd)
      Bundler.with_clean_env do
        Dir.chdir(@app_path) do |app_path|
          result = system(cmd, @system_options)
          if !result
            raise Apcera::Error::ExecuteError.new("failed to execute: #{cmd}.\n")
          end

          result
        end
      end
    rescue => e
      fail e
    end

    # Extract the package to a given location.
    def extract(location)
      @app_path = File.join(@root_path, location)
      Dir.mkdir(@app_path) unless Dir.exists?(@app_path)

      execute_app("tar -zxf #{@pkg_path}")
    rescue => e
      fail e
    end

    # Upload the new package to the staging coordinator
    def upload
      execute_app("tar czf #{@updated_pkg_path} .")

      sha1 = Digest::SHA1.file(@updated_pkg_path)
      File.open(@updated_pkg_path, "rb") do |f|
        response = RestClient.post(@stager_url+"/data?sha1=#{sha1.to_s}", f.read, { :content_type => "application/octet-stream" } )
      end
    rescue => e
      fail e
    end

    # Snapshot the stager filesystem for app
    def snapshot
      response = RestClient.post(@stager_url+"/snapshot", {})
    rescue => e
      fail e
    end

    # Add environment variable to package.
    def environment_add(key, value)
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "environment",
        :action => "add",
        :key => key,
        :value => value
      })
    rescue => e
      fail e
    end

    # Delete environment variable from package.
    def environment_remove(key, value)
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "environment",
        :action => "remove",
        :key => key,
        :value => value
      })
    rescue => e
      fail e
    end

    # Add provides to package.
    def provides_add(type, name)
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "provides",
        :action => "add",
        :type => type,
        :name => name
      })
    rescue => e
      fail e
    end

    # Delete provides from package.
    def provides_remove(key, value)
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "provides",
        :action => "remove",
        :type => type,
        :name => name
      })
    rescue => e
      fail e
    end

    # Add dependencies to package.
    def dependencies_add(type, name)
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "dependencies",
        :action => "add",
        :type => type,
        :name => name
      })
    rescue => e
      fail e
    end

    # Delete dependencies from package.
    def dependencies_remove(type, name)
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "dependencies",
        :action => "remove",
        :type => type,
        :name => name
      })
    rescue => e
      fail e
    end

    # Add template to package.
    def templates_add(path, left_delimiter = "{{", right_delimiter = "}}")
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "templates",
        :action => "add",
        :path => path,
        :left_delimiter => left_delimiter,
        :right_delimiter => right_delimiter
      })
    rescue => e
      fail e
    end

    # Delete template from package.
    def templates_remove(path, left_delimiter = "{{", right_delimiter = "}}")
      response = RestClient.post(@stager_url+"/meta", {
        :resource => "templates",
        :action => "remove",
        :path => path,
        :left_delimiter => left_delimiter,
        :right_delimiter => right_delimiter
      })
    rescue => e
      fail e
    end

    # Get metadata for the package being staged.
    def meta
      response = RestClient.get(@stager_url+"/meta")
      return JSON.parse(response.to_s)
    rescue => e
      output_error "Error: #{e.message}.\n"
      raise e
    end

    # Tell the staging coordinator you are done.
    def done
      response = RestClient.post(@stager_url+"/done", {})
      exit0r 0
    rescue => e
      fail e
    end

    # Tell the staging coordinator you need to relaunch.
    def relaunch
      response = RestClient.post(@stager_url+"/relaunch", {})
      exit0r 0
    rescue => e
      fail e
    end

    # Finish staging, compress your app dir and send to the staging coordinator.
    # Then tell the staging coordinator we are done.
    def complete
      upload
      done
    end

    # Returns the start command for the package.
    def start_command
      self.meta["environment"]["START_COMMAND"]
    end

    # Easily set the start command
    def start_command=(val)
      self.environment_add("START_COMMAND", val)
    end

    # Returns the start path for the package.
    def start_path
      self.meta["environment"]["START_PATH"]
    end

    # Easily set the start path
    def start_path=(val)
      self.environment_add("START_PATH", val)
    end

    # Fail the stager, something went wrong.
    def fail(error = nil)
      output_error "Error: #{error.message}.\n" if error
      RestClient.post(@stager_url+"/failed", {})
    rescue => e
      output_error "Error: #{e.message}.\n"
    ensure
      exit0r 1
    end

    # Exit, needed for tests to not quit.
    def exit0r(code)
      exit code
    end

    # Output to stderr
    def output_error(text)
      $stderr.puts text
    end

    # Output to stdout
    def output(text)
      $stdout.puts text
    end

    private

    def setup_environment
      # When staging we use the root path. These are overridden in tests.
      @root_path = "/"
      @pkg_path = File.join(@root_path, PKG_NAME)
      @updated_pkg_path = File.join(@root_path, UPDATED_PKG_NAME)
      @system_options = {}
    end
  end
end
