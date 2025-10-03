FROM ruby:3.4

WORKDIR /app

COPY . .

RUN gem install bundler && bundle install

ENTRYPOINT ["ruby", "/app/entrypoint.rb"]
