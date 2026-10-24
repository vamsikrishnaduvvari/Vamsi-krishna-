FROM jenkins/jenkins:lts-jdk21

USER root
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
RUN apt-get update && apt-get install -y --no-install-recommends \
      ansible docker.io \
    && rm -rf /var/lib/apt/lists/*
USER jenkins
