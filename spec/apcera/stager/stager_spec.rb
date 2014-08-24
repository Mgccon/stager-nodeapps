require 'spec_helper'

describe Apcera::Stager do
  it "should initialize" do
    stager = Apcera::Stager.new
    stager.class.should == Apcera::Stager
  end
end
