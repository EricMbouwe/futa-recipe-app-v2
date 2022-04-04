FROM ruby:3.0.3-alpine3.14

MAINTAINER dondanidang@gmail.com

# install dependencies for application
RUN apk add --no-cache --update build-base \
                                linux-headers \
                                less \
                                git \
                                postgresql-dev \
                                nodejs \
                                tzdata
RUN rm -rf /var/cache/apk/*

# navigate to app directory
ENV APP_PATH /opt/app
RUN mkdir -p $APP_PATH
WORKDIR $APP_PATH

# copy Gemfile*
COPY Gemfile .
COPY Gemfile.lock .

# install gems
RUN gem install bundler:1.16.3
RUN bundle install --jobs `expr $(cat /proc/cpuinfo | grep -c "cpu cores") - 1` --retry 3

COPY . .

EXPOSE 3000
