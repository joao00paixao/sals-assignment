FROM ruby:2.6.5

RUN apt-get update && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    git \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* 

WORKDIR /usr/src/app 

RUN git clone https://github.com/salsify/gifmachine.git . 

COPY entrypoint.sh /usr/src/app/

RUN chmod +x /usr/src/app/entrypoint.sh 

EXPOSE 4567

ENTRYPOINT ["/usr/src/app/entrypoint.sh"] 