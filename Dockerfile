# ---- Base image (Apache + PHP) ----
FROM registry.access.redhat.com/ubi9/php-83:latest

USER 0

# Tools needed to build oci8 + unzip instant client
RUN dnf -y install unzip gcc make autoconf php-devel php-pear libaio && \
    dnf clean all

# ---- Oracle Instant Client ----
# Copy the ZIPs from your repo into the image
COPY oracle/instantclient-basiclite.zip /tmp/instantclient-basiclite.zip
COPY oracle/instantclient-sdk.zip /tmp/instantclient-sdk.zip

RUN mkdir -p /opt/oracle && \
    unzip -q /tmp/instantclient-basiclite.zip -d /opt/oracle && \
    unzip -q /tmp/instantclient-sdk.zip -d /opt/oracle && \
    rm -f /tmp/instantclient-*.zip && \
    ln -s /opt/oracle/instantclient_* /opt/oracle/instantclient

# Runtime linker path
RUN echo "/opt/oracle/instantclient" > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig

# ---- Install OCI8 extension ----
# PECL asks for the instantclient path; we provide it non-interactively
RUN printf "instantclient,/opt/oracle/instantclient\n" | pecl install oci8 && \
    echo "extension=oci8.so" > /etc/php.d/20-oci8.ini

# Optional: useful defaults
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient
ENV ORACLE_HOME=/opt/oracle/instantclient

# ---- Copy app source ----
# UBI php image expects app in /opt/app-root/src
COPY . /opt/app-root/src

# Ensure permissions for random OpenShift UID
RUN chgrp -R 0 /opt/app-root/src && chmod -R g=u /opt/app-root/src

USER 1001

# Apache listens on 8080 in OpenShift images
EXPOSE 8080

