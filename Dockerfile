FROM ubuntu:latest
LABEL Scott Ueland (https://github.com/bnhf)
ENV LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive

RUN echo Starting. \
 && apt-get -q -y update \
 && apt-get -q -y install --no-install-recommends apcupsd dbus libapparmor1 libdbus-1-3 libexpat1 tzdata \
 && apt-get -q -y install postfix libsasl2-modules mailutils jq \
 && apt-get -q -y full-upgrade \
 && rm -rif /var/lib/apt/lists/* \
 && mkdir /opt/apcupsd \
 && mv /etc/apcupsd/* /opt/apcupsd \
 && echo Finished.

COPY scripts /opt/apcupsd
COPY postfix /etc/postfix
COPY start.sh /

CMD /start.sh
