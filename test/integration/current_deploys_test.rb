require_relative '../test_helper'

class AngularTest < ActionDispatch::IntegrationTest
  let(:admin_user) { users(:admin) }

  before(:each) do
    stub_request(:get, /status.github.com/).to_return(body: '{"status":"good","last_updated":"2014-12-12T00:00:00Z"}')
    login_as_user(admin_user)
  end

  it 'visits default project page' do
    visit('/projects')
    current_path.must_equal '/projects'
    find_link('Project').visible?.must_equal true
    find_link('Project')[:href].must_equal '/projects/foo'

    find_link('Production Pod').visible?.must_equal true
    find_link('Production').visible?.must_equal true
    find_link('Staging').visible?.must_equal true
  end

  it "visits fixture Production Pod's stage page" do
    visit('/projects')
    current_path.must_equal '/projects'
    click_link('Production Pod')
    current_path.must_equal '/projects/foo/stages/production-pod'
  end

  it 'visits recent deploys page' do
    visit('/deploys/recent')
    current_path.must_equal '/deploys/recent'
    all('tr').count.must_equal 3
    all('tr')[1].all('td')[0].text.must_equal 'Project'
    all('tr')[1].all('td')[1].text.must_equal 'Super Admin'
    all('tr')[1].all('td')[2].text.must_equal 'staging is about to deploy to Staging'
    all('tr')[1].all('td')[4].text.must_equal 'pending'

    all('tr')[2].all('td')[0].text.must_equal 'Project'
    all('tr')[2].all('td')[1].text.must_equal 'Super Admin'
    all('tr')[2].all('td')[2].text.must_equal 'staging was deployed to Staging'
    all('tr')[2].all('td')[4].text.must_equal 'succeeded'
  end

  it 'visits current deploys page' do
    visit('/deploys/active')
    current_path.must_equal '/deploys/active'
    all('tr').count.must_equal 2
    all('tr')[1].all('td')[0].text.must_equal 'Project'
    all('tr')[1].all('td')[1].text.must_equal 'Super Admin'
    all('tr')[1].all('td')[2].text.must_equal 'staging is about to deploy to Staging'
    all('tr')[1].all('td')[4].text.must_equal 'pending'
  end
end
