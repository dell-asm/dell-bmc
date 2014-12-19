require 'spec_helper'
describe 'bmc' do

  context 'with defaults for all parameters' do
    it { should contain_class('bmc') }
  end
end
