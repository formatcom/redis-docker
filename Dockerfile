FROM redis:5.0.5-alpine

RUN apk add --no-cache sed bash

COPY redis.conf /usr/local/etc/redis/redis.conf
COPY run.sh /run.sh

RUN chmod +x /run.sh

CMD ["/run.sh"]

ENTRYPOINT [ "bash", "-c" ]
