FROM base
RUN apt-get update
RUN apt-get install -y -q software-properties-common
RUN apt-get install -y -q python-software-properties
RUN apt-add-repository ppa:brightbox/ruby-ng
RUN apt-get update
RUN apt-get install -y -q git
RUN apt-get install -y -q curl
RUN apt-get install -y -q ruby2.1 ruby2.1-dev
RUN apt-get install -y -q build-essential
RUN apt-get install -y -q nodejs
RUN gem install bundler
ADD . /dashboard/
WORKDIR /dashboard
RUN bundle install
EXPOSE 3030
CMD ["dashing", "start"] 
