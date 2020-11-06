FROM circleci/elixir:1.11.2

USER root
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
    chromium \
    ghostscript \
    openjdk-11-jre \
    poppler-utils \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir /opt/verapdf
WORKDIR /opt/verapdf
RUN wget http://downloads.verapdf.org/rel/verapdf-installer.zip \
  && unzip verapdf-installer.zip \
  && mv verapdf-greenfield* verapdf-greenfield \
  && chmod +x verapdf-greenfield/verapdf-install
COPY auto-install.xml /opt/verapdf/verapdf-greenfield
RUN ./verapdf-greenfield/verapdf-install auto-install.xml

WORKDIR /opt/zuv
RUN wget https://github.com/ZUGFeRD/ZUV/releases/download/v0.8.3/ZUV-0.8.3.jar
ENV ZUV_JAR /opt/zuv/ZUV-0.8.3.jar

USER circleci
WORKDIR /home/circleci
