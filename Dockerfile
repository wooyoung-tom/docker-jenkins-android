FROM ubuntu:20.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y git curl dpkg gpg tar && rm -rf /var/lib/apt/lists/*

# disable user interaction
ARG DEBIAN_FRONTEND=noninteractive

# install openjdk
RUN apt-get update && \
apt-get install -y unzip && \
apt-get install -y wget && \
apt-get install -y vim && \
apt-get install -y openjdk-11-jdk

# add gradle
ARG GRADLE_VER=7.2
ENV GRADLE_ZIP gradle-${GRADLE_VER}-all.zip
ENV GRADLE_URL https://services.gradle.org/distributions/${GRADLE_ZIP}
ENV GRADLE_HOME /opt/gradle/gradle-${GRADLE_VER}-all

ADD ${GRADLE_URL} /opt/
RUN unzip /opt/${GRADLE_ZIP} -d /opt/ && rm /opt/${GRADLE_ZIP}

# add android sdk
ENV ANDROID_SDK_ROOT /opt/android-sdk

ARG ANDROID_SDK_VER=7583922
ENV ANDROID_SDK_ZIP commandlinetools-linux-${ANDROID_SDK_VER}_latest.zip
ENV ANDROID_SDK_URL https://dl.google.com/android/repository/${ANDROID_SDK_ZIP}

ADD ${ANDROID_SDK_URL} /opt/
RUN unzip -q /opt/${ANDROID_SDK_ZIP} -d ${ANDROID_SDK_ROOT} && rm /opt/${ANDROID_SDK_ZIP}

# PATH setup
ENV PATH $PATH:$GRADLE_HOME/bin
ENV PATH $PATH:$ANDROID_SDK_ROOT/cmdline-tools/bin/

RUN echo yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT "platform-tools" "build-tools;30.0.3"
RUN echo yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT "platform-tools" "platforms;android-30"

RUN chmod -R 755 $ANDROID_SDK_ROOT

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME=/var/jenkins_home

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Install git lfs per https://github.com/git-lfs/git-lfs#from-binary
# Avoid JENKINS-59569 - git LFS 2.7.1 fails clone with reference repository
ARG GIT_LFS_VERSION=v2.11.0
ENV GIT_LFS_VERSION $GIT_LFS_VERSION
ENV GIT_BASE_URL=https://github.com/git-lfs/git-lfs/releases/download/
RUN curl -fsSLO ${GIT_BASE_URL}${GIT_LFS_VERSION}/git-lfs-linux-$(dpkg --print-architecture)-${GIT_LFS_VERSION}.tar.gz \
  && curl -fsSLO ${GIT_BASE_URL}${GIT_LFS_VERSION}/sha256sums.asc \
  && curl -L https://github.com/bk2204.gpg | gpg --no-tty --import \
  && gpg -d sha256sums.asc | grep git-lfs-linux-$(dpkg --print-architecture)-${GIT_LFS_VERSION}.tar.gz | sha256sum -c \
  && tar -zvxf git-lfs-linux-$(dpkg --print-architecture)-${GIT_LFS_VERSION}.tar.gz git-lfs \
  && mv git-lfs /usr/bin/ \
  && rm -rf git-lfs-linux-$(dpkg --print-architecture)-${GIT_LFS_VERSION}.tar.gz sha256sums.asc /root/.gnupg

# Jenkins is run with user `jenkins`, uid = 1000
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN mkdir -p $JENKINS_HOME \
  && chown ${uid}:${gid} $JENKINS_HOME \
  && groupadd -g ${gid} ${group} \
  && useradd -d "$JENKINS_HOME" -u ${uid} -g ${gid} -m -s /bin/bash ${user}

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes
ARG TINI_VERSION=v0.16.1
COPY tini_pub.gpg ${JENKINS_HOME}/tini_pub.gpg
RUN curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) -o /sbin/tini \
  && curl -fsSL https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture).asc -o /sbin/tini.asc \
  && gpg --no-tty --import ${JENKINS_HOME}/tini_pub.gpg \
  && gpg --verify /sbin/tini.asc \
  && rm -rf /sbin/tini.asc /root/.gnupg \
  && chmod +x /sbin/tini

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.303.1}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=4aae135cde63e398a1f59d37978d97604cb595314f7041d2d3bac3f0bb32c065

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV JENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementals
RUN chown -R ${user} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE ${http_port}

# will be used by attached agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${user}

# Invoke Git LFS
RUN git lfs install

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY tini-shim.sh /bin/tini
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN install-plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
