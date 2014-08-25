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

  it "should initialize with the stager url" do
    stager = Apcera::Stager.new({:stager_url => @stager_url})
    stager.class.should == Apcera::Stager
    stager.stager_url.should == @stager_url
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

      # We don't want to exit in tests.
      @stager.stub(:exit0r)
      @stager.stub(:output_error)
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
        VCR.use_cassette('valid_download') do
          @stager.download
        end
        File.exists?(@stager.pkg_path).should == true
      end

      it "should bubble errors to fail" do
        @stager.stub(:exit0r) { raise }

        VCR.use_cassette('invalid_download') do
          expect { @stager.download }.to raise_error(Apcera::Error::PackageDownloadError)
        end
      end
    end

    context "extract" do
      it "should decompress the package to a supplied path" do
        VCR.use_cassette('valid_download') do
          @stager.download
        end

        @stager.extract(@appdir)
        File.exists?(File.join(@stager.root_path, @appdir)).should == true
      end

      it "should throw errors" do
        @stager.stub(:execute_app).and_raise

        VCR.use_cassette('valid_download') do
          @stager.download
        end

        expect { @stager.extract(@appdir) }.to raise_error
      end
    end

    context "upload" do
      it "should compress a new package and send to the staging coordinator" do
        VCR.use_cassette('valid_download') do
          @stager.download
        end

        @stager.extract(@appdir)

        VCR.use_cassette('upload') do
          @stager.upload
        end

        File.exists?(File.join(@stager.root_path, "#{@appdir}.tar.gz"))
      end

      it "should bubble errors to fail" do
        @stager.stub(:exit0r).with(1) { raise }

        VCR.use_cassette('valid_download') do
          @stager.download
        end

        @stager.extract(@appdir)

        VCR.use_cassette('invalid_upload') do
          expect { @stager.upload }.to raise_error
        end
      end
    end

    context "complete" do
      it "should compress a new package and send to the staging coordinator then be done" do
        VCR.use_cassette('valid_download') do
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

        VCR.use_cassette('valid_download') do
          @stager.download
        end

        @stager.extract(@appdir)

        VCR.use_cassette('invalid_complete') do
          expect { @stager.complete }.to raise_error
        end
      end
    end

    context "snapshot" do
      it "should send a snapshot request to the staging coordinator" do
        VCR.use_cassette('valid_download') do
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

        VCR.use_cassette('valid_download') do
          @stager.download
        end
        @stager.extract(@appdir)
        VCR.use_cassette('invalid_snapshot') do
          expect { @stager.snapshot }.to raise_error
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
        @stager.should_receive(:exit0r).with(1) { raise }

        VCR.use_cassette('invalid_fail') do
          expect { @stager.fail }.to raise_error
        end
      end
    end

    context "metadata" do
      it "should recieve package metadata" do
        VCR.use_cassette('metadata') do
          @stager.metadata.class.should == Hash
        end
      end

      it "should throw errors" do
        VCR.use_cassette('invalid_metadata') do
          expect { @stager.metadata }.to raise_error(Apcera::Error::PackageMetadataError)
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

        VCR.use_cassette('invalid_relaunch') do
          expect { @stager.relaunch }.to raise_error
        end
      end
    end
  end
end
