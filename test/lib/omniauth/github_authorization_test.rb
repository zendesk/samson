# frozen_string_literal: true
require_relative '../../test_helper'
require 'omniauth/github_authorization'

SingleCov.covered!

describe Omniauth::GithubAuthorization do
  let(:teams) { [] }
  let(:organization) { config.organization }
  let(:organization_member) { true }
  let(:config) { Rails.application.config.samson.github }
  let(:authorization) { Omniauth::GithubAuthorization.new('test.user', '123') }

  before do
    if organization
      stub_github_api("orgs/#{organization}/teams", teams)
      stub_github_api("orgs/#{organization}/members/test.user", {}, organization_member ? 204 : 404)

      teams.each do |team|
        stub_github_api("teams/#{team[:id]}/members/test.user", {}, team[:member] ? 204 : 404)
      end
    else
      config.stubs(organization: nil)
    end
  end

  describe 'when not part of the organization' do
    let(:organization_member) { false }

    it 'is not allowed to view' do
      authorization.role_id.must_be_nil
    end
  end

  describe 'when no organization is set' do
    let(:organization) { false }

    it 'is allowed to view' do
      authorization.role_id.must_equal(Role::VIEWER.id)
    end
  end

  describe 'with no teams' do
    it 'keeps the user a viewer' do
      authorization.role_id.must_equal(Role::VIEWER.id)
    end
  end

  describe 'with an admin team' do
    let(:teams) do
      [
        {id: 1, slug: config.admin_team, member: member?}
      ]
    end

    describe 'as a team member' do
      let(:member?) { true }

      it 'updates the user to admin' do
        authorization.role_id.must_equal(Role::ADMIN.id)
      end
    end

    describe 'not a team member' do
      let(:member?) { false }

      it 'does not update the user to admin' do
        authorization.role_id.must_equal(Role::VIEWER.id)
      end
    end
  end

  describe 'with a deploy team' do
    let(:teams) do
      [
        {id: 2, slug: config.deploy_team, member: member?}
      ]
    end

    describe 'as a team member' do
      let(:member?) { true }

      it 'updates the user to admin' do
        authorization.role_id.must_equal(Role::DEPLOYER.id)
      end
    end

    describe 'not a team member' do
      let(:member?) { false }
      it 'does not update the user to admin' do
        authorization.role_id.must_equal(Role::VIEWER.id)
      end
    end
  end

  describe 'with both teams' do
    let(:teams) do
      [
        {id: 1, slug: config.admin_team, member: true},
        {id: 2, slug: config.deploy_team, member: true}
      ]
    end

    it 'updates the user to admin' do
      authorization.role_id.must_equal(Role::ADMIN.id)
    end
  end
end
