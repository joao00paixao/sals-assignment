#!/bin/bash
set -e 

export PGPASSWORD=$POSTGRES_PASSWORD

until psql -h localhost -U postgres -c '\q'; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is up - executing commands" 

gem install bundler -v 2.4.22
bundle install
bundle exec rake localhost:create
bundle exec rake localhost:migrate

exec ruby app.rb -o 0.0.0.0
