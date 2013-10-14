FROM base
RUN apt-get update
RUN apt-get install -y -q git
RUN apt-get install -y -q curl
RUN apt-get install -y -q ruby1.9.3
RUN apt-get install -y -q build-essential
RUN apt-get install -y -q nodejs
RUN gem install bundler
ADD . /dashboard/
WORKDIR /dashboard
RUN bundle install
EXPOSE 3030
CMD ["dashing", "start"] 
