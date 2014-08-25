require 'spec_helper'

describe Apcera::Stager do
  before do
    @appdir = "site"

    # See mock server directory for setup!
    @stager_url = "http://example.com"
  end

  it "should raise an exception when initialized without a stager url" do
    expect { Apcera::Stager.new }.to raise_error(Apcera::Error::StagerURLRequired)
  end

  it "should initialize with the stager url passed as an argument" do
    stager = Apcera::Stager.new({:stager_url => @stager_url})
    stager.class.should == Apcera::Stager
    stager.stager_url.should == @stager_url
  end

  it "should initialize when the ENV variable STAGER_URL is present" do
    begin
      ENV["STAGER_URL"] = @stager_url
      stager = Apcera::Stager.new
      stager.class.should == Apcera::Stager
      stager.stager_url.should == @stager_url
    ensure
      ENV["STAGER_URL"] = nil
    end
  end

  context do
    before do
      @stager = Apcera::Stager.new({:stager_url => @stager_url})

      # Best way to get our current path is to get the gem_dir!
      spec = Gem::Specification.find_by_name("apcera-stager-api").gem_dir

      # Lets write files in spec/tmp for tests!
      @stager.root_path = File.join(spec, "spec", "tmp")
      @stager.pkg_path = File.join(@stager.root_path, "pkg.tar.gz")
      @stager.updated_pkg_path = File.join(@stager.root_path, "updated.tar.gz")
      @stager.system_options = { :out => "/dev/null", :err => "/dev/null" }

      # We don't want to exit in tests.
      @stager.stub(:exit0r)
      @stager.stub(:output_error)
      @stager.stub(:output)
    end

    after do
      # Don't trust urls above, they could be changed in tests.
      # This does an actual delete and we want to be specific.
      spec = Gem::Specification.find_by_name("apcera-stager-api").gem_dir
      test_files = File.join(spec, "spec", "tmp", "*")

      # Remove the test files.
      FileUtils.rm_rf Dir.glob(test_files)
    end

    context "download" do
      it "should download the app package to pkg.tar.gz" do
        VCR.use_cassette('download') do
          @stager.download
        end
        File.exists?(@stager.pkg_path).should == true
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/download') do
          expect { @stager.download }.to raise_error(RestClient::ResourceNotFound, "404 Resource Not Found")
        end
      end
    end

    context "extract" do
      it "should decompress the package to a supplied path" do
        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)
        File.exists?(File.join(@stager.root_path, @appdir)).should == true
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        err = Apcera::Error::ExecuteError.new
        @stager.should_receive(:execute_app).and_raise(err)

        VCR.use_cassette('download') do
          @stager.download
        end

        expect { @stager.extract(@appdir) }.to raise_error(err)
      end
    end

    context "execute" do
      it "should execute commands" do
        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        @stager.execute("cat thing").should == nil
        @stager.execute("cat #{File.join(@stager.app_path, "app", "Gemfile")}").should == true
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        cmd = "cat thing"
        expect {@stager.execute(cmd) }.to raise_error(Apcera::Error::ExecuteError, "failed to execute: #{cmd}.\n")
      end
    end

    context "execute_app" do
      it "should execute commands in app dir" do
        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        @stager.execute_app("cat thing").should == nil
        @stager.execute_app("cat #{File.join("app", "Gemfile")}").should == true
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        cmd = "cat thing"
        expect {@stager.execute_app(cmd) }.to raise_error(Apcera::Error::ExecuteError, "failed to execute: #{cmd}.\n")
      end
    end

    context "upload" do
      it "should compress a new package and send to the staging coordinator" do
        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        VCR.use_cassette('upload') do
          @stager.upload
        end

        File.exists?(File.join(@stager.root_path, "#{@appdir}.tar.gz"))
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        VCR.use_cassette('invalid/upload') do
          expect { @stager.upload }.to raise_error(RestClient::ResourceNotFound, "404 Resource Not Found")
        end
      end
    end

    context "complete" do
      it "should compress a new package and send to the staging coordinator then be done" do
        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        VCR.use_cassette('complete') do
          @stager.complete
        end

        File.exists?(File.join(@stager.root_path, "#{@appdir}.tar.gz"))
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('download') do
          @stager.download
        end

        @stager.extract(@appdir)

        VCR.use_cassette('invalid/complete') do
          expect { @stager.complete }.to raise_error(RestClient::ResourceNotFound, "404 Resource Not Found")
        end
      end
    end

    context "done" do
      it "should send done to the staging coordinator" do
        @stager.should_receive(:exit0r).with(0)

        VCR.use_cassette('done') do
          @stager.done
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/done') do
          expect { @stager.done }.to raise_error(RestClient::ResourceNotFound, "404 Resource Not Found")
        end
      end
    end

    context "snapshot" do
      it "should send a snapshot request to the staging coordinator" do
        VCR.use_cassette('download') do
          @stager.download
        end
        @stager.extract(@appdir)
        VCR.use_cassette('snapshot') do
          @stager.snapshot
        end
        VCR.use_cassette('done') do
          @stager.done
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('download') do
          @stager.download
        end
        @stager.extract(@appdir)
        VCR.use_cassette('invalid/snapshot') do
          expect { @stager.snapshot }.to raise_error(RestClient::ResourceNotFound, "404 Resource Not Found")
        end
      end
    end

    context "fail" do
      it "should have a fail hook" do
        # Make sure we don't exit and that we called exit 1.
        @stager.should_receive(:exit0r).with(1)

        VCR.use_cassette('fail') do
          @stager.fail.should == "OK"
        end
      end

      it "should exit no matter what" do
        # Make sure we don't exit and that we called exit 1.
        @stager.should_receive(:exit0r).with(1)

        VCR.use_cassette('invalid/fail') do
          @stager.fail
        end
      end
    end

    context "metadata" do
      it "should recieve package metadata and cache it" do
        VCR.use_cassette('metadata') do
          @stager.metadata.class.should == Hash
        end
      end

      it "should throw errors" do
        VCR.use_cassette('invalid/metadata') do
          expect { @stager.metadata }.to raise_error(RestClient::ResourceNotFound, "404 Resource Not Found")
        end
      end
    end

    context "relaunch" do
      it "should allow you to trigger a stager relaunch" do
        @stager.should_receive(:exit0r).with(0) { 0 }

        VCR.use_cassette('relaunch') do
          @stager.relaunch.should == 0
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/relaunch') do
          expect { @stager.relaunch }.to raise_error(RestClient::ResourceNotFound, "404 Resource Not Found")
        end
      end
    end

    context "start_command" do
      it "should return the package start command" do
        VCR.use_cassette('metadata') do
          @stager.start_command.should == "./startme"
        end
      end
    end

    context "start_path" do
      it "should return the package start path" do
        VCR.use_cassette('metadata') do
          @stager.start_path.should == "/app"
        end
      end
    end

    context "environment_add" do
      it "should add an environment variable" do
        VCR.use_cassette('environment_add') do
          @stager.environment_add("TEST_VAR", "foo")
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/environment_add') do
          expect { @stager.environment_add("TEST_VAR", "foo") }.to raise_error
        end
      end
    end

    context "environment_remove" do
      it "should environment_remove an environment variable" do
        VCR.use_cassette('environment_remove') do
          @stager.environment_remove("TEST_VAR", "foo")
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/environment_remove') do
          expect { @stager.environment_remove("TEST_VAR", "foo") }.to raise_error
        end
      end
    end

    context "provides_add" do
      it "should add to its list of provides" do
        VCR.use_cassette('provides_add') do
          @stager.provides_add("os", "linux")
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/provides_add') do
          expect { @stager.provides_add("os", "linux") }.to raise_error
        end
      end
    end

    context "provides_remove" do
      it "should remove from its list of provides" do
        VCR.use_cassette('provides_remove') do
          @stager.provides_remove("os", "linux")
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/provides_remove') do
          expect { @stager.provides_remove("os", "linux") }.to raise_error
        end
      end
    end

    context "dependencies_add" do
      it "should add to its list of dependencies" do
        VCR.use_cassette('dependencies_add') do
          @stager.dependencies_add("os", "linux")
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/dependencies_add') do
          expect { @stager.dependencies_add("os", "linux") }.to raise_error
        end
      end
    end

    context "dependencies_remove" do
      it "should remove from its list of dependencies" do
        VCR.use_cassette('dependencies_remove') do
          @stager.dependencies_remove("os", "linux")
        end
      end

      it "should bubble errors to fail" do
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid/dependencies_remove') do
          expect { @stager.dependencies_remove("os", "linux") }.to raise_error
        end
      end
    end

    context "exit0r" do
      before do
        @stager.unstub(:exit0r)
      end

      it "should wrap successful exit" do
        begin
          @stager.exit0r(0)
        rescue SystemExit => e
          e.status.should == 0
        end
      end

      it "should wrap errored exit" do
        begin
          @stager.exit0r(1)
        rescue SystemExit => e
          e.status.should == 1
        end
      end
    end
  end
end
