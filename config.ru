require "./routes/pusher.rb"

EventMachine.kqueue = true
EventMachine.epoll

run Pusher
