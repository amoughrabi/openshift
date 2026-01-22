# Apache + PHP 8.3 on UBI9 (OpenShift-friendly)
FROM registry.redhat.io/ubi10/php-83:latest

USER 0

# Build deps for oci8 + unzip instant client
RUN dnf -y install unzip gcc make autoconf php-devel php-pear libaio && \
    dnf clean all

# ---- Oracle Instant Client (place these in your repo) ----
# oracle/instantclient-basiclite.zip
# oracle/instantclient-sdk.zip
COPY oracle/instantclient-basiclite.zip /tmp/instantclient-basiclite.zip
COPY oracle/instantclient-sdk.zip /tmp/instantclient-sdk.zip

# Unzip into separate dirs to avoid interactive overwrite prompts,
# then merge into one /opt/oracle/instantclient folder.
RUN set -eux; \
    mkdir -p /opt/oracle/ic-basiclite /opt/oracle/ic-sdk /opt/oracle/instantclient; \
    unzip -oq /tmp/instantclient-basiclite.zip -d /opt/oracle/ic-basiclite; \
    unzip -oq /tmp/instantclient-sdk.zip -d /opt/oracle/ic-sdk; \
    rm -f /tmp/instantclient-*.zip; \
    cp -a /opt/oracle/ic-basiclite/instantclient_*/* /opt/oracle/instantclient/; \
    cp -a /opt/oracle/ic-sdk/instantclient_*/* /opt/oracle/instantclient/; \
    # Linker config
    echo "/opt/oracle/instantclient" > /etc/ld.so.conf.d/oracle-instantclient.conf; \
    ldconfig; \
    # Sanity check
    test -f /opt/oracle/instantclient/libclntsh.so || ls -la /opt/oracle/instantclient

# ---- Install & enable OCI8 ----
RUN set -eux; \
    printf "instantclient,/opt/oracle/instantclient\n" | pecl install oci8; \
    echo "extension=oci8.so" > /etc/php.d/20-oci8.ini

# Runtime env for Oracle libs
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient \
    ORACLE_HOME=/opt/oracle/instantclient

# ---- Copy app source ----
# UBI php s2i images expect app source here
COPY . /opt/app-root/src

# Make it work with OpenShift random UID (group 0)
RUN chgrp -R 0 /opt/app-root/src && chmod -R g=u /opt/app-root/src

ENV DOCUMENTROOT=/opt/app-root/src/public

USER 1001
EXPOSE 8080
CMD ["/usr/libexec/s2i/run"]
