require "./routes/pusher.rb"

# Needed for process watching
EventMachine.epoll if EventMachine.epoll?
EventMachine.kqueue = true if EventMachine.kqueue?

run Pusher
