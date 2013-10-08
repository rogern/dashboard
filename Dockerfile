FROM base
RUN apt-get update
RUN apt-get install -y -q git
RUN apt-get install -y -q curl
RUN apt-get install -y -q ruby1.9.3
RUN apt-get install -y -q build-essential
RUN apt-get install -y -q nodejs
RUN gem install bundler
RUN git clone https://github.com/joscarsson/dashboard 
WORKDIR /dashboard
RUN bundle install
ADD config.yml /dashboard/config.yml
EXPOSE 3030
CMD ["dashing", "start"] 
