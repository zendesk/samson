# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe GkeCluster do
  describe 'validations' do
    def gke_cluster(overrides = {})
      attrs = {
        gcp_project: 'gp',
        cluster_name: 'cn',
        zone: 'zn'
      }.merge(overrides)

      GkeCluster.new(attrs)
    end

    it 'is invalid if it is missing a gcp_project' do
      refute_valid_on gke_cluster(gcp_project: nil), :gcp_project, "Gcp project can't be blank"
    end

    it 'is invalid if it is missing a cluster_name' do
      refute_valid_on gke_cluster(cluster_name: nil), :cluster_name, "Cluster name can't be blank"
    end

    it 'is invalid if it is missing a zone' do
      refute_valid_on gke_cluster(zone: nil), :zone, "Zone can't be blank"
    end
  end
end
