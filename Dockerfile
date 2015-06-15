FROM tatsushid/tinycore-ruby:2.2

USER tc
RUN tce-load -wic git

USER root

RUN wget -O /usr/local/bin/docker \
    https://get.docker.io/builds/Linux/x86_64/docker-1.6.2 \
    && chmod +x /usr/local/bin/docker

WORKDIR /app
COPY . .

RUN gem build dockit.gemspec && gem install dockit*.gem && rm -rf *

ENTRYPOINT ["dockit"]
