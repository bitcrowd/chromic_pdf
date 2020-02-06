FROM circleci/elixir:1.9.4

USER root
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
    chromium \
    ghostscript \
    openssh-client \
    ca-certificates \
	&& rm -rf /var/lib/apt/lists/*
