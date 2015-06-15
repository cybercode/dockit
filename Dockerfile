FROM ubuntu:14.10

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -qy software-properties-common \
    && apt-add-repository -y ppa:brightbox/ruby-ng \
    && apt-get update && apt-get upgrade -y \
    && apt-get install -y build-essential ruby2.2 ruby2.2-dev git-core \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app
COPY . .

RUN gem build dockit.gemspec && gem install dockit*.gem
RUN rm -rf *

ENTRYPOINT ["dockit"]
