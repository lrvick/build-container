ARG DOCKER_IMAGE_HASH
ARG DEBIAN_IMAGE_HASH

FROM docker@sha256:${DOCKER_IMAGE_HASH} as docker

FROM debian@sha256:${DEBIAN_IMAGE_HASH} as build

ARG CLOUD_SDK_VERSION
ARG BUILDX
ARG GIT_CHGLOG_VERSION

# janky janky janky
ENV PATH /google-cloud-sdk/bin:$PATH

ADD files /
RUN apt-install

# Install gcloud
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  tar xzf google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  rm google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image

# Install aws (TODO: alpine 3.15 should have s3cmd as a package)
RUN pip3 install s3cmd

# Install azure
RUN pip3 install azure-cli

# Required by docker-compose for zlib.
ENV LD_LIBRARY_PATH=/lib:/usr/lib

# Install buildx
RUN curl --create-dirs -Lo /root/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/${BUILDX}/buildx-${BUILDX}.linux-amd64 \
  && chmod 755 /root/.docker/cli-plugins/docker-buildx

# Install git-chglog
RUN curl -Lo /usr/local/bin/git-chglog https://github.com/git-chglog/git-chglog/releases/download/${GIT_CHGLOG_VERSION}/git-chglog_linux_amd64
RUN chmod +x /usr/local/bin/git-chglog

# Install codecov
RUN curl -o codecov https://codecov.io/bash
RUN curl https://raw.githubusercontent.com/codecov/codecov-bash/master/SHA512SUM | head -n 1 | shasum -a 512 -c
RUN chmod +x codecov && mv codecov /usr/local/bin/

# Install custom scripts
ADD hack/scripts/ /usr/local/bin/

COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/
