FROM docker.io/library/alpine:3.23
ENV RUNNING_IN_DOCKER=true
ENTRYPOINT ["/bin/bash"]
CMD ["/app/guitos_exporter.sh"]
COPY guitos_exporter.sh /app/guitos_exporter.sh
RUN addgroup -g 10001 user \
    && adduser -H -D -u 10000 -G user user
RUN apk add --quiet --no-cache bash coreutils curl jq
USER user:user