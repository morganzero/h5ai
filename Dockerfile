FROM nginx:1.25-alpine3.17 AS builder
LABEL maintainer="morganzero@sushibox.dev" \
      description="Alpine-based container with Nginx 1.25, PHP 8.1, hosting h5ai 0.30.0."

RUN apk add --no-cache wget unzip

RUN wget https://release.larsjung.de/h5ai/h5ai-0.30.0.zip
RUN unzip h5ai-0.30.0.zip -d /usr/share/h5ai
RUN rm h5ai-0.30.0.zip

FROM nginx:1.25-alpine3.17

RUN apk add --no-cache \
    bash bash-completion supervisor tzdata shadow \
    php81 php81-fpm php81-session php81-json php81-xml php81-mbstring php81-exif \
    php81-intl php81-gd php81-pecl-imagick php81-zip php81-opcache \
    ffmpeg imagemagick zip apache2-utils patch

ENV PUID=911
ENV PGID=911
ENV TZ='Europe/Berlin'
ENV HTPASSWD='false'
ENV HTPASSWD_USER='guest'
ENV HTPASSWD_PW=''

RUN addgroup -g "$PGID" abc && adduser -D -u "$PUID" -G abc abc

COPY h5ai.conf /etc/nginx/conf.d/h5ai.conf
COPY php_set_timezone.ini /etc/php81/conf.d/00_timezone.ini
COPY php_set_jit.ini /etc/php81/conf.d/00_jit.ini
COPY php_set_memory_limit.ini /etc/php81/conf.d/00_memlimit.ini
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY --from=builder /usr/share/h5ai /usr/share/h5ai

RUN sed -i.bak 's/worker_processes  1/worker_processes  auto/g' /etc/nginx/nginx.conf
RUN mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak

ADD start.sh /
ADD h5ai.conf.htpasswd.patch /

RUN chmod a+x /start.sh

EXPOSE 80
VOLUME [ "/config", "/h5ai" ]
ENTRYPOINT [ "/start.sh" ]
