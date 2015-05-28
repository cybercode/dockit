FROM ubuntu:14.10

RUN apt-get update && apt-get install -qy software-properties-common
RUN apt-add-repository -y ppa:brightbox/ruby-ng
RUN apt-get update && apt-get upgrade -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential libpq-dev \
    ruby2.2 ruby2.2-dev git-core nodejs

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN gem install bundler --no-ri --no-rdoc
RUN bundle config --global frozen 1

WORKDIR /dockit
COPY . .
RUN bundle --without development test doc

RUN ln -s /dockit/bin/dockit /usr/bin/

ENTRYPOINT ["/usr/bin/dockit"]
