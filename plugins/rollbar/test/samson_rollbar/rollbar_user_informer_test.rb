# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbar::RollbarUserInformer do
  let(:env) { { 'rollbar.exception_uuid' => '1234' } }
  let(:body) { ['Original <!-- ROLLBAR ERROR --> Body', 'continues'] }
  let(:response) { [200, {}, body] }
  let(:app) { SamsonRollbar::RollbarUserInformer.new(->(_env) { response }) }
  let(:call) { app.call(env) }
  let(:expected_body_with_replacement) { 'Original before 1234 after Body' }

  before { SamsonRollbar::RollbarUserInformer.user_information = 'before {{error_uuid}} after' }

  describe '#call' do
    it 'informs the user of the error' do
      call.must_equal(
        [
          200,
          {"Content-Length" => "40", "Error-Id" => "1234"},
          [expected_body_with_replacement, "continues"]
        ]
      )
    end

    it 'does nothing when the error uuid is not given' do
      SamsonRollbar::RollbarUserInformer.expects(:replacement).never

      app.call({}).must_equal([200, {}, ["Original <!-- ROLLBAR ERROR --> Body", "continues"]])
    end

    it 'does nothing when user information is not given' do
      SamsonRollbar::RollbarUserInformer.user_information = nil

      SamsonRollbar::RollbarUserInformer.expects(:replacement).never

      app.call({}).must_equal([200, {}, ["Original <!-- ROLLBAR ERROR --> Body", "continues"]])
    end

    it 'can handle empty body' do
      body.clear
      call.must_equal([200, { "Content-Length" => "0", "Error-Id" => "1234" }, []])
    end

    describe 'using custom placeholder' do
      let(:body) { ["Original <!-- CUSTOM PLACEHOLDER --> Body", "continues"] }

      it 'can use custom placeholder' do
        original_placeholder = SamsonRollbar::RollbarUserInformer.user_information_placeholder
        begin
          SamsonRollbar::RollbarUserInformer.user_information_placeholder = "<!-- CUSTOM PLACEHOLDER -->"
          call.must_equal(
            [
              200,
              {"Content-Length" => "40", "Error-Id" => "1234"},
              [expected_body_with_replacement, "continues"]
            ]
          )
        ensure
          SamsonRollbar::RollbarUserInformer.user_information_placeholder = original_placeholder
        end
      end
    end

    describe "when body is an IO" do
      fake_io_body = Class.new do
        def initialize(content)
          @content = content
          @closed = false
        end

        def each(&block)
          @content.each(&block)
        end

        def close
          @closed = true
        end

        def closed?
          @closed
        end
      end
      let(:body) { fake_io_body.new(['Original <!-- ROLLBAR ERROR --> Body', 'continues']) }

      it "closes old body so it can be garbadge collected" do
        body.expects(:close).once
        call.must_equal(
          [
            200,
            { "Content-Length" => "40", "Error-Id" => "1234" },
            [expected_body_with_replacement, "continues"]
          ]
        )
      end

      it "closes old body so it can be garbadge collected when an exception happens during replacement" do
        body.expects(:each).raises(ArgumentError) # make `replace_placeholder` blow up
        body.expects(:close).once
        assert_raises ArgumentError do
          call
        end
      end
    end
  end
end
