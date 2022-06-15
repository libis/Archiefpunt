FROM ruby:2.7.6-alpine

RUN bundle config --global frozen 1
#RUN useradd abv -u 10000 -m -d /app
RUN addgroup -S abv -g 10000 && adduser -S abv -u 10000 -G abv && apk --no-cache add g++ make bash

WORKDIR /app
COPY Gemfile.docker Gemfile

COPY app app
COPY lib lib
COPY public public
COPY cache cache
COPY gems gems
COPY config.ru config.ru
COPY run.sh run.sh
ADD config.tgz ./

RUN chmod a+x cache && chown -R abv:abv /app
USER abv:abv
RUN gem install gems/solis-0.36.0.gem
RUN bundle install
RUN gem cleanup minitest

EXPOSE 9292
#DEBUG PORT
EXPOSE 1234:1234
EXPOSE 26162:26162

ENV LANG C.UTF-8
CMD /app/run.sh
