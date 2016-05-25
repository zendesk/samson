require_relative '../../test_helper'

SingleCov.covered! uncovered: 9

describe Changeset::PullRequest do
  DataStruct = Struct.new(:user, :merged_by, :body, :title)
  UserStruct = Struct.new(:login)

  let(:project) { projects(:test) }
  let(:data) { DataStruct.new(user, merged_by, body) }
  let(:pr) { Changeset::PullRequest.new("xxx", data) }
  let(:user) { UserStruct.new("foo") }
  let(:merged_by) { UserStruct.new("bar") }
  let(:body) { "" }

  describe ".find" do
    it "finds the pull request" do
      GITHUB.stubs(:pull_request).with("foo/bar", 42).returns(data)
      data.title = "Make it bigger!"

      pr = Changeset::PullRequest.find("foo/bar", 42)

      pr.title.must_equal "Make it bigger!"
    end

    it "returns nil if the pull request could not be found" do
      GITHUB.stubs(:pull_request).with("foo/bar", 42).raises(Octokit::NotFound)

      pr = Changeset::PullRequest.find("foo/bar", 42)

      pr.must_be_nil
    end
  end

  describe ".changeset_from_webhook" do
    it 'finds the pull request' do
      webhook_data = {'number' => 42, 'pull_request' => {'state' => 'open'}}
      pr = Changeset::PullRequest.changeset_from_webhook(project, webhook_data)

      pr.state.must_equal 'open'
    end
  end

  describe "#users" do
    it "returns the users associated with the pull request" do
      pr.users.map(&:login).must_equal ["foo", "bar"]
    end

    it "excludes duplicate users" do
      merged_by.stubs(:login).returns("foo")
      pr.users.map(&:login).must_equal ["foo"]
    end

    describe 'nil users' do
      let(:merged_by) { nil }

      it 'excludes nil users' do
        pr.users.map(&:login).must_equal ['foo']
      end
    end
  end

  describe "#title_without_jira" do
    before do
      GITHUB.stubs(:pull_request).with("foo/bar", 42).returns(data)
      Changeset::PullRequest.find("foo/bar", 42)
    end

    it "scrubs the JIRA from the PR title (with square brackets)" do
      data.stubs(:title).returns("[VOICE-1233] Make it bigger!")
      pr.title_without_jira.must_equal "Make it bigger!"
    end

    it "scrubs the JIRA from the PR title (without square brackets)" do
      data.stubs(:title).returns("VOICE-123 Make it bigger!")
      pr.title_without_jira.must_equal "Make it bigger!"
    end
  end

  describe "#jira_issues" do
    let(:data_nil_body) { stub("data", user: user, body: nil, title: nil) }
    let(:pr_no_body) { Changeset::PullRequest.new("xxx", data_nil_body) }
    let(:jira_url) { "https://jira.zendesk.com/browse/" }

    before do
      @original_jira_url_env = ENV['JIRA_BASE_URL']
      ENV['JIRA_BASE_URL'] = nil # delete for consistent test environment
    end

    after do
      ENV['JIRA_BASE_URL'] = @original_jira_url_env
    end

    it "returns a list of JIRA issues referenced in the PR body" do
      body.replace(<<-BODY)
        Fixes https://foobar.atlassian.net/browse/XY-123 and
        https://foobar.atlassian.net/browse/AB-666
      BODY

      pr.jira_issues.must_equal [
        Changeset::JiraIssue.new("https://foobar.atlassian.net/browse/XY-123"),
        Changeset::JiraIssue.new("https://foobar.atlassian.net/browse/AB-666")
      ]
    end

    it "returns an empty array if there are no JIRA references" do
      pr.jira_issues.must_equal []
    end

    it "returns an empty array if body is missing" do
      pr_no_body.jira_issues.must_equal []
    end

    it "returns a list of JIRA urls using JIRA_BASE_URL ENV var given JIRA codes" do
      ENV['JIRA_BASE_URL'] = 'https://foo.atlassian.net/browse/'
      body.replace(<<-BODY)
        Fixes XY-123 and AB-666
      BODY

      pr.jira_issues.must_equal [
        Changeset::JiraIssue.new("https://foo.atlassian.net/browse/XY-123"),
        Changeset::JiraIssue.new("https://foo.atlassian.net/browse/AB-666")
      ]
    end

    it "returns JIRA URLs from both title and body" do
      ENV['JIRA_BASE_URL'] = 'https://foo.atlassian.net/browse/'
      body.replace(<<-BODY)
        Fixes issue in title and AB-666
      BODY
      data.title = "XY-123: Make it bigger!"

      pr.jira_issues.must_equal [
        Changeset::JiraIssue.new("https://foo.atlassian.net/browse/XY-123"),
        Changeset::JiraIssue.new("https://foo.atlassian.net/browse/AB-666")
      ]
    end

    it "returns an empty array if JIRA_BASE_URL ENV var is not set when given JIRA codes" do
      ENV['JIRA_BASE_URL'] = nil
      body.replace(<<-BODY)
        Fixes XY-123 and AB-666
      BODY

      pr.jira_issues.must_equal []
    end

    it "returns an empty array if invalid URLs are given" do
      body.replace(<<-BODY)
        Fixes https://foobar.atlassian.net/browse/XY-123k
      BODY

      pr.jira_issues.must_equal []
    end

    it "uses full JIRA urls when given, falling back to JIRA_BASE_URL" do
      ENV['JIRA_BASE_URL'] = 'https://foo.atlassian.net/browse/'
      body.replace(<<-BODY)
        Fixes https://foobar.atlassian.net/browse/XY-123 and AB-666
      BODY

      pr.jira_issues.must_equal [
        Changeset::JiraIssue.new("https://foobar.atlassian.net/browse/XY-123"),
        Changeset::JiraIssue.new("https://foo.atlassian.net/browse/AB-666")
      ]
    end

    it "uses full URL if given and not auto-generate even when JIRA_BASE_URL is set" do
      ENV['JIRA_BASE_URL'] = 'https://foo.atlassian.net/browse/'
      body.replace(<<-BODY)
        Fixes XY-123, see https://foobar.atlassian.net/browse/XY-123
      BODY

      pr.jira_issues.must_equal [
        Changeset::JiraIssue.new("https://foobar.atlassian.net/browse/XY-123")
      ]
    end

    single_key_cases = [
      ["ABC-123",                "ABC-123"], # exactly the key
      ["ABC-124 text",           "ABC-124"], # starting line with key
      ["message ABC-123",        "ABC-123"], # ending line with key
      ["message ABC-123 text",   "ABC-123"], # separated by whitespaces
      ["message\nABC-123\ntext", "ABC-123"], # separated by newlines
      ["message\rABC-123\rtext", "ABC-123"], # separated by carriage returns
      ["message.ABC-123.text",   "ABC-123"], # separated by dots
      ["message:ABC-123:text",   "ABC-123"], # separated by colons
      ["message,ABC-123,text",   "ABC-123"], # separated by commas
      ["message;ABC-123;text",   "ABC-123"], # separated by semicolons
      ["message&ABC-123&text",   "ABC-123"], # separated by ampersands
      ["message=ABC-123=text",   "ABC-123"], # separated by equal signs
      ["message?ABC-123?text",   "ABC-123"], # separated by question marks
      ["message!ABC-123!text",   "ABC-123"], # separated by exclamation marks
      ["message/ABC-123/text",   "ABC-123"], # separated by slashes
      ["message\\ABC-123\\text", "ABC-123"], # separated by back slashes
      ["message~ABC-123~text",   "ABC-123"], # separated by tildas
    ]
    single_key_cases.each do |casebody, key|
      it "returns #{key} when given \"#{casebody}\"" do
        ENV['JIRA_BASE_URL'] = jira_url
        full_url = jira_url + key
        body.replace(casebody)
        pr.jira_issues.must_equal [Changeset::JiraIssue.new(full_url)]
      end
    end

    keys_with_number_cases = [
      ["A1BC-123",                "A1BC-123"], # exactly the key
      ["AB8C-123 text",           "AB8C-123"], # starting line with key
      ["message A7BC-123",        "A7BC-123"], # ending line with key
      ["message A7BC-123\r\n",    "A7BC-123"], # ending line with key
      ["message AB9C-123 text",   "AB9C-123"], # separated by whitespaces
      ["message\nA2BC-123\ntext", "A2BC-123"], # separated by newlines
      ["message\rABC0-123\rtext", "ABC0-123"], # separated by carriage returns
      ["mes\r\nABC0-123\r\ntext", "ABC0-123"], # separated by CRLF
      ["mssge.ABC789-123.text", "ABC789-123"], # separated by dots
      ["message:A1BC-123:text",   "A1BC-123"], # separated by colons
      ["message,A1BC-123,text",   "A1BC-123"], # separated by commas
      ["message;A1BC-123;text",   "A1BC-123"], # separated by semicolons
      ["message&AB1C-123&text",   "AB1C-123"], # separated by ampersands
      ["message=A1BC-123=text",   "A1BC-123"], # separated by equal signs
      ["message?A1BC-123?text",   "A1BC-123"], # separated by question marks
      ["message!AB1C-123!text",   "AB1C-123"], # separated by exclamation marks
      ["message/AB1C-123/text",   "AB1C-123"], # separated by slashes
      ["message\\A1BC-123\\text", "A1BC-123"], # separated by back slashes
      ["message~A1BC-123~text",   "A1BC-123"]  # separated by tildas
    ]
    keys_with_number_cases.each do |casebody, key|
      it "returns #{key} when given \"#{casebody}\"" do
        ENV['JIRA_BASE_URL'] = jira_url
        full_url = jira_url + key
        body.replace(casebody)
        pr.jira_issues.must_equal [Changeset::JiraIssue.new(full_url)]
      end
    end

    multiple_keys_cases = [
      ["ABC-123 DEF-456",                 ["ABC-123", "DEF-456"]], # exactly the keys
      ["message ABD-123 DEF-456 text",    ["ABD-123", "DEF-456"]], # separated by whitespaces
      ["message\nABC-123\nDEF-456\ntext", ["ABC-123", "DEF-456"]], # separated by newlines
      ["message\rABC-123\rDEF-457\rtext", ["ABC-123", "DEF-457"]], # separated by carriage returns
      ["message.ABC-123.DEF-456.text",    ["ABC-123", "DEF-456"]], # separated by dots
      ["message:ABC-123:DEF-456:text",    ["ABC-123", "DEF-456"]], # separated by colons
      ["message,ABC-123,DEF-456,text",    ["ABC-123", "DEF-456"]], # separated by commas
      ["message;ABC-123;DEF-456;text",    ["ABC-123", "DEF-456"]], # separated by semicolons
      ["message&ABC-123&DEF-456&text",    ["ABC-123", "DEF-456"]], # separated by ampersands
      ["message=ABC-123=DEF-456=text",    ["ABC-123", "DEF-456"]], # separated by equal signs
      ["message?ABC-123?DEF-456?text",    ["ABC-123", "DEF-456"]], # separated by question marks
      ["message!ABC-123!DEF-456!text",    ["ABC-123", "DEF-456"]], # separated by exclamation marks
      ["message/ABC-123/DEF-456/text",    ["ABC-123", "DEF-456"]], # separated by slashes
      ["message\\ABC-123\\DEF-456\\text", ["ABC-123", "DEF-456"]], # separated by back slashes
      ["message~ABC-123~DEF-456~text",    ["ABC-123", "DEF-456"]], # separated by tildas
    ]
    multiple_keys_cases.each do |casebody, keys|
      it "returns #{keys} when given \"#{casebody}\"" do
        ENV['JIRA_BASE_URL'] = jira_url
        body.replace(casebody)
        pr.jira_issues.must_equal keys.map { |x| Changeset::JiraIssue.new(jira_url + x) }
      end
    end

    no_key_cases = [
      "message without key",
      "message ABC-A text",
      "message M-123 invalid key",
      "message MES- invalid key",
      "message -123 invalid key",
      "message 1ABC-123 invalid key",
      "message 123-123 invalid key",
      "does not parse key0MES-123",
      "does not parse MES-123key",
      "MES-123k invalid char",
      "invalid char MES-123k"
    ]
    no_key_cases.each do |casebody|
      it "returns [] when given \"#{casebody}\"" do
        body.replace(casebody)
        pr.jira_issues.must_equal []
      end
    end
  end

  describe "#risks" do
    def add_risks
      body.replace(<<-BODY.strip_heredoc)
        # Risks
         - Explosions
      BODY
    end

    def no_risks
      body.replace(<<-BODY.strip_heredoc)
        Not that risky ...
      BODY
    end

    before { add_risks }

    it "finds risks" do
      pr.risks.must_equal "- Explosions"
    end

    it "caches risks" do
      pr.risks
      no_risks
      pr.risks.must_equal "- Explosions"
    end

    it "does not find - None" do
      body.replace(<<-BODY.strip_heredoc)
        # Risks
         - None
      BODY
      pr.risks.must_equal nil
    end

    it "does not find None" do
      body.replace(<<-BODY.strip_heredoc)
        # Risks
        None
      BODY
      pr.risks.must_equal nil
    end

    it "finds risks with underline style markdown headers" do
      body.replace(<<-BODY.strip_heredoc)
        Risks
        =====
          - Snakes
      BODY
      pr.risks.must_equal "- Snakes"
    end

    it "finds risks with closing hashes in atx style markdown headers" do
      body.replace(<<-BODY.strip_heredoc)
        ## Risks ##
          - Planes
      BODY
      pr.risks.must_equal "- Planes"
    end

    context "with nothing risky" do
      before { no_risks }

      it "finds nothing" do
        pr.risks.must_equal nil
      end

      it "caches nothing" do
        pr.risks
        add_risks
        pr.risks.must_equal nil
      end
    end
  end
end
