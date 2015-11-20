FROM cybercode/alpine-ruby
ENV DOCKER_VERSION=1.9.1 BIN=/usr/local/bin/docker

RUN apk --update add curl ruby-json && curl -sSL -o $BIN \
    https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION \
    && chmod +x $BIN && apk del curl

WORKDIR /app
COPY . .
RUN apk --update add --virtual build_deps \
    build-base ruby-dev libc-dev linux-headers git \
    && gem build dockit.gemspec \
    && gem install --no-rdoc --no-ri dockit*.gem \
    && apk del build_deps && rm -rf /app

WORKDIR /
ENTRYPOINT ["dockit"]
