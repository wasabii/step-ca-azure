FROM smallstep/step-ca:0.14.3
USER root
RUN \
    apk add --update libcap openssl jq dos2unix && rm -rf /var/cache/apk/* && \
    mkdir /step && \
    mkdir /mnt/step && \
    setcap 'cap_net_bind_service=+eip' /usr/local/bin/step-ca
COPY init.sh /step/init.sh
COPY ca.json /step/ca.json
COPY defaults.json /step/defaults.json
RUN  \
     dos2unix /step/init.sh && \
     dos2unix /step/ca.json && \
     dos2unix /step/defaults.json && \
     chmod +x /step/init.sh && \
     apk del dos2unix && rm -rf /var/cache/apk/*
USER step
ENV  STEPPATH=/home/step
ENV  PORT=443
ENV  DNS_NAME=
ENV  AAD_TENANT_ID=
ENV  AAD_CLIENT_ID=
ENV  AAD_CLIENT_SECRET=
ENV  CA_NAME=
ENV  CA_ROOT=
ENV  CA_ROOT_KEYVAULTID=
ENV  DELAY=0
CMD  /bin/sh -c "sleep $DELAY && /step/init.sh && /usr/local/bin/step-ca $STEPPATH/config/ca.json || sleep 60"
