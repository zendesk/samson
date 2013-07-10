require_relative 'spec_helper'

describe CommandTail do
  describe "tailing a command" do
    let(:messages) {[]}

    before do
      Timeout.timeout(5) do
        EventMachine.run do
          tail = CommandTail.new("echo 'hi'", proc {|message|
            messages << message
            EventMachine.stop
          })

          EventMachine.add_shutdown_hook do
            tail.close
          end
        end
      end
    end

    it "should contain 'hi'" do
      messages.should == ["hi\r\n"]
    end
  end
end
