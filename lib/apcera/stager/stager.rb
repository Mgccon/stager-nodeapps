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

    # Setup /stagerfs chroot environment so it is ready to run commands
    # from pulled in dependencies. This does the following:
    # - Setup working resolv.conf
    # - Bind mounts /proc to /stagerfs/proc
    # - Recursively bind mounts /dev to /stagerfs/dev
    def setup_chroot
      execute("sudo mkdir -p /stagerfs/etc")
      execute("sudo cp /etc/resolv.conf /stagerfs/etc/resolv.conf")

      execute("sudo mkdir -p /stagerfs/proc")
      execute("sudo mount --bind /proc /stagerfs/proc")

      execute("sudo mkdir -p /stagerfs/dev")
      execute("sudo mount --rbind /dev /stagerfs/dev")
    end

    # Download a package from the staging coordinator.
    # We use Net::HTTP here because it supports streaming downloads.
    def download
      uri = URI(@stager_url + "/data")

      Net::HTTP.start(uri.host.to_s, uri.port.to_s) do |http|
        request = Net::HTTP::Get.new uri.request_uri

        http.request request do |response|
          if response.code.to_i == 200
            open @pkg_path, 'wb' do |io|
              response.read_body do |chunk|
                io.write chunk
              end
            end
          else
            raise Apcera::Error::DownloadError.new("package download failed.\n")
          end
        end
      end
    rescue => e
      fail e
    end

    # Execute a command in the shell.
    # We don't want real commands in tests.
    def execute(*cmd)
      Bundler.with_clean_env do
        result = system(*cmd, @system_options)
        if !result
          raise Apcera::Error::ExecuteError.new("failed to execute: #{cmd.join(' ')}.\n")
        end

        result
      end
    rescue => e
      fail e
    end

    # Execute a command in the directory your package was extracted to (or where
    # you manually set @app_dir). Useful helper.
    def execute_app(*cmd)
      raise_app_path_error if @run_path == nil
      Bundler.with_clean_env do
        Dir.chdir(@run_path) do |run_path|
          result = system(*cmd, @system_options)
          if !result
            raise Apcera::Error::ExecuteError.new("failed to execute: #{cmd.join(' ')}.\n")
          end

          result
        end
      end
    rescue => e
      fail e
    end

    # Extract the package to a location within staging path, optionally creating
    # the named folder first and extract into it. If a location parameter is
    # given, when upload is run the folder will be uploaded up along with the
    # files.  In either case, execute_app will run commands in the location
    # where files were extracted to.
    def extract(location="")
      @app_path=File.join(@root_path, "staging")
      Dir.mkdir(@app_path) unless Dir.exists?(@app_path)

      @run_path = location.empty? ? @app_path : File.join(@app_path, location)
      Dir.mkdir(@run_path) unless Dir.exists?(@run_path)

      execute_app("tar -zxf #{@pkg_path}")
    rescue => e
      fail e
    end

    # Upload the new package to the staging coordinator. If we have an app
    # extracted we send that to the staging coordinator. If no app was ever
    # extracted it is a noop.
    def upload
      if @app_path == nil
        unless File.exist?(@pkg_path)
          download
        end

        upload_file(@pkg_path)
      else
        # Use execute instead of execute_app so that if the user provided a dir
        # to extract into it results in the uploaded package being wrapped in
        # that directory.
        execute("cd #{@app_path} && tar czf #{@updated_pkg_path} ./*")

        upload_file(@updated_pkg_path)
      end
    rescue => e
      fail e
    end

    # Snapshot the stager filesystem for app.
    def snapshot
      response = RestClient.post(@stager_url+"/snapshot", {})
    rescue => e
      fail e
    end

    # Add environment variable to package.
    def environment_add(key, value)
      response = RestClient.put(stager_meta_url, {
        :resource => "environment",
        :action => "add",
        :key => key,
        :value => value
      })
    rescue => e
      fail e
    end

    # Delete environment variable from package.
    def environment_remove(key)
      response = RestClient.put(stager_meta_url, {
        :resource => "environment",
        :action => "remove",
        :key => key
      })
    rescue => e
      fail e
    end

    # Add provides to package.
    def provides_add(type, name)
      response = RestClient.put(stager_meta_url, {
        :resource => "provides",
        :action => "add",
        :type => type,
        :name => name
      })
    rescue => e
      fail e
    end

    # Delete provides from package.
    def provides_remove(type, name)
      response = RestClient.put(stager_meta_url, {
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
      exists = self.meta["dependencies"].detect { |dep| dep["type"] == type && dep["name"] == name }
      return false if exists

      response = RestClient.put(stager_meta_url, {
        :resource => "dependencies",
        :action => "add",
        :type => type,
        :name => name
      })

      true
    rescue => e
      fail e
    end

    # Delete dependencies from package.
    def dependencies_remove(type, name)
      exists = self.meta["dependencies"].detect { |dep| dep["type"] == type && dep["name"] == name}
      return false if !exists

      response = RestClient.put(stager_meta_url, {
        :resource => "dependencies",
        :action => "remove",
        :type => type,
        :name => name
      })

      true
    rescue => e
      fail e
    end

    # Add template to package.
    def templates_add(path, left_delimiter = "{{", right_delimiter = "}}")
      response = RestClient.put(stager_meta_url, {
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
      response = RestClient.put(stager_meta_url, {
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
      response = RestClient.get(stager_meta_url)
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

    # Easily set the start command.
    def start_command=(val)
      self.environment_add("START_COMMAND", val)
    end

    # Returns the start path for the package.
    def start_path
      self.meta["environment"]["START_PATH"]
    end

    # Easily set the start path.
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

    # Output to stderr.
    def output_error(text)
      $stderr.puts text
    end

    # Output to stdout
    def output(text)
      $stdout.puts text
    end

    # Set @app_path, the location that will uploaded.  Also updates location
    # where execute_app will run commands from.
    def app_path=(value)
      @app_path=value
      @run_path=value
    end

    private

    def raise_app_path_error
      raise Apcera::Error::AppPathError.new("app path not set, please run extract!\n")
    end

    def setup_environment
      # When staging we use the root path. These are overridden in tests.
      @root_path = "/tmp"
      @pkg_path = File.join(@root_path, PKG_NAME)
      @updated_pkg_path = File.join(@root_path, UPDATED_PKG_NAME)
      @system_options = {}
    end

    def stager_meta_url
      @stager_url + "/meta"
    end

    def upload_file(file)
      sha256 = Digest::SHA256.file(file)
      File.open(file, "rb") do |f|
        response = RestClient.post(@stager_url+"/data?sha256=#{sha256.to_s}", f, { :content_type => "application/octet-stream" } )
      end
    end
  end
end
