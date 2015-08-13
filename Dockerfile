FROM tatsushid/tinycore-ruby:2.2
ENV DOCKER_VERSION=1.8.1
USER tc
RUN tce-load -wic git

USER root

RUN wget -O /usr/local/bin/docker \
    https://get.docker.io/builds/Linux/x86_64/docker-$DOCKER_VERSION \
    && chmod +x /usr/local/bin/docker

WORKDIR /app
COPY . .

RUN gem build dockit.gemspec && gem install dockit*.gem && rm -rf *

ENTRYPOINT ["dockit"]
