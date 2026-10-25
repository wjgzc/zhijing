FROM docker.io/library/eclipse-temurin:17-jdk
WORKDIR /work
RUN chmod 1777 /work
USER 65534:65534
ENV LANG=C.UTF-8
