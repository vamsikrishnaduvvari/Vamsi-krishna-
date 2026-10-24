FROM jenkins/jenkins:lts-jdk21

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
      ansible docker.io \
    && rm -rf /var/lib/apt/lists/*
USER jenkins
