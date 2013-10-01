web: puma -C config/puma.rb -p 8080
worker: env TERM_CHILD=1 bundle exec rake resque:work
