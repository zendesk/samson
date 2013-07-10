Pusher.class_eval do
  namespace "/tasks" do
    get "/new" do
      erb :"tasks/new"
    end
  end
end
