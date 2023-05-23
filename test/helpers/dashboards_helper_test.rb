# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DashboardsHelper do
  describe '#project_multi_deploys?' do
    it 'has no warnings for same deploy across all deploy groups' do
      prep_versions('v1.0')
      project_has_different_deploys?(@versions[1]).must_equal false
    end

    it 'has warnings for different deploy across all deploy groups' do
      prep_versions('v1.1')
      project_has_different_deploys?(@versions[1]).must_equal true
    end
  end

  describe '#dashboard_project_row_style' do
    it 'returns blank style for same versions' do
      prep_versions('v1.0')
      dashboard_project_row_style(1).must_equal ''
    end

    it 'returns warning for different versions' do
      prep_versions('v1.1')
      dashboard_project_row_style(1).must_equal 'class=warning'
    end

    it 'returns no-deploys for no versions' do
      prep_versions('v1.0')
      dashboard_project_row_style(0).must_equal 'class=no-deploys'
    end
  end

  describe '#display_version' do
    before do
      prep_versions('v2.0')
      Project.first.update_attribute('id', 1)
      Deploy.where(reference: 'v1.0').first.update_attribute('id', 1)
    end

    it 'returns blank for empty version' do
      display_version(0, 1).must_equal ''
    end

    it 'returns correct link' do
      display_version(1, 1).must_equal link_to('v2.0', project_deploy_path(1, 1))
    end
  end

  def prep_versions(ref)
    @versions = Hashie::Mash.new(
      0 => {},
      1 => {
        1 => {reference: ref, id: 1},
        2 => {reference: 'v1.0'},
        3 => {reference: 'v1.0'}
      }
    )
  end
end
