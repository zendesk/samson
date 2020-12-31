# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe Stage do
  let(:stage1) { stages(:test_staging) }
  let(:stage2) { stages(:test_production) }
  let(:stage3) { stages(:test_production_pod) }

  before do
    stage1.update!(prerequisite_stage_ids: [stage2.id, stage3.id])
  end

  describe '#prerequisite_stages' do
    it 'returns prerequisite stages' do
      stage1.prerequisite_stages.must_equal [stage2, stage3]
    end

    it 'returns an empty array if no prerequisite stages' do
      stage1.update!(prerequisite_stage_ids: [])
      stage1.prerequisite_stages.must_equal []
    end
  end

  describe '#undeployed_prerequisite_stages' do
    let(:job) { jobs(:succeeded_test) }

    it 'returns empty array if there are no prereq stages' do
      stage1.update!(prerequisite_stage_ids: [])

      assert_sql_queries(0) do
        stage1.undeployed_prerequisite_stages('123').must_equal []
      end
    end

    it 'returns empty array if ref has been deployed to all prereq stages' do
      stage3.deploys << deploys(:failed_staging_test)
      stage1.prerequisite_stages.each { |s| s.deploys.first.update_column(:job_id, job.id) }

      assert_sql_queries(2) do
        stage1.undeployed_prerequisite_stages(job.commit).must_equal []
      end
    end

    it 'returns prereq stages where ref has not been deployed yet' do
      stage2.deploys.first.update_column(:job_id, job.id)

      assert_sql_queries(2) do
        stage1.undeployed_prerequisite_stages(job.commit).must_equal [stage3]
      end
    end
  end

  describe '#validate_prerequisites' do
    it 'removes empty values' do
      stage1.prerequisite_stage_ids = [stage2.id, '']

      stage1.send(:validate_prerequisites)

      stage1.prerequisite_stage_ids.must_equal [stage2.id]
    end

    it 'converts ids to integers' do
      stage1.prerequisite_stage_ids = ['1', '2']

      stage1.send(:validate_prerequisites)

      stage1.prerequisite_stage_ids.must_equal [1, 2]
    end

    it 'adds an error if deadlock stages exist' do
      stage2.update_attribute(:prerequisite_stage_ids, [stage1.id])

      stage1.prerequisite_stage_ids.must_include stage2.id
      stage1.send(:validate_prerequisites).must_equal false

      stage1.errors.full_messages.must_equal ['Stage(s) Production already list this stage as a prerequisite.']
    end

    it 'returns true if there are no errors' do
      stage1.send(:validate_prerequisites).must_equal true
    end
  end
end
