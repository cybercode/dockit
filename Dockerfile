FROM alpine:3.6

RUN apk update && apk upgrade && apk --update add docker \
    ruby ruby-irb ruby-rake ruby-io-console ruby-bigdecimal ruby-json ruby-bundler \
    libstdc++ tzdata bash ca-certificates \
    &&  echo 'gem: --no-document' > /etc/gemrc

RUN apk update && apk upgrade && apk add docker

WORKDIR /app
COPY . .
RUN apk add --virtual build_deps \
    build-base ruby-dev libc-dev linux-headers git \
    && gem build dockit.gemspec \
    && gem install --no-rdoc --no-ri dockit*.gem \
    && apk del build_deps && rm -rf /app

WORKDIR /
ENTRYPOINT ["dockit"]
