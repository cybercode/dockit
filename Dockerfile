FROM cybercode/alpine-ruby:2.3

RUN apk --update add docker

WORKDIR /app
COPY . .
RUN apk add --virtual build_deps \
    build-base ruby-dev libc-dev linux-headers git \
    && gem build dockit.gemspec \
    && gem install --no-rdoc --no-ri dockit*.gem \
    && apk del build_deps && rm -rf /app

WORKDIR /
ENTRYPOINT ["dockit"]
