FROM smallstep/step-ca:0.14.3
USER root
RUN \
    apk add --update libcap openssl jq && rm -rf /var/cache/apk/* && \
    mkdir /step && \
    mkdir /mnt/step && \
    setcap 'cap_net_bind_service=+eip' /usr/local/bin/step-ca
COPY init.sh /step/init.sh
COPY ca.json /step/ca.json
COPY defaults.json /step/defaults.json
USER step
ENV  STEPPATH=/home/step
ENV  PORT=443
ENV  DNS_NAME=
ENV  CA_NAME=
ENV  CA_SECRET_ID=
CMD  /bin/sh -c "/step/init.sh && /usr/local/bin/step-ca $STEPPATH/config/ca.json"
