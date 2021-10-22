FROM ruby:3.0.1

RUN apt-get update -y
RUN apt-get dist-upgrade -y
RUN apt-get install libsodium-dev -y

RUN gem install discordrb
RUN gem install google-cloud-compute-v1

#COPY ./src/ /amsc/
