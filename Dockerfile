FROM ruby:3.0.5

WORKDIR /app

# Copy bare minimum files to install gems
COPY Gemfile aws-google.gemspec /app/
COPY lib /app/lib
RUN bundle install
