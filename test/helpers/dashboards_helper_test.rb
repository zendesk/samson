require_relative '../test_helper'

SingleCov.covered!

describe DashboardsHelper do
  describe '#project_multi_deploys?' do
    it 'has no warnings for same deploy across all deploy groups' do
      deploys = Hashie::Mash.new(
        '1' => { reference: 'v1.0' },
        '2' => { reference: 'v1.0' },
        '3' => { reference: 'v1.0' }
      )
      project_has_different_deploys?(deploys).must_equal false
    end

    it 'has warnings for different deploy across all deploy groups' do
      deploys = Hashie::Mash.new(
        '1' => { reference: 'v1.0' },
        '2' => { reference: 'v1.1' },
        '3' => { reference: 'v1.0' }
      )
      project_has_different_deploys?(deploys).must_equal true
    end
  end
end
