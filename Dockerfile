FROM    ubuntu:trusty
RUN apt-get -y update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y language-pack-en
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales

# -------------------- #
#     Installation     #
# -------------------- #

# install carbon & graphite
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
    python-ldap python-cairo python-django python-twisted \
    python-django-tagging python-simplejson python-memcache \
    python-pysqlite2 python-support python-pip gunicorn \
    supervisor nginx-light collectd \
    build-essential python-dev
RUN pip install 'Twisted==14.0.0' Django==1.5 whisper bucky && \
    pip install --install-option="--prefix=/var/lib/graphite" --install-option="--install-lib=/var/lib/graphite/lib" carbon && \
    pip install --install-option="--prefix=/var/lib/graphite" --install-option="--install-lib=/var/lib/graphite/webapp" graphite-web
RUN adduser --system --group --no-create-home collectd

# grafana
RUN mkdir /var/lib/grafana && cd /var/lib/grafana && \
    wget -nv http://grafanarel.s3.amazonaws.com/grafana-1.9.1.tar.gz -O grafana.tar.gz && \
    tar zxf grafana.tar.gz --strip-components=1 && \
    rm -rf grafana.tar.gz

# --------------------- #
#     Configuration     #
# --------------------- #

COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configure graphite & carbon
COPY ./initial_data.json /var/lib/graphite/webapp/graphite/initial_data.json
COPY ./local_settings.py /var/lib/graphite/webapp/graphite/local_settings.py
COPY ./carbon.conf /var/lib/graphite/conf/carbon.conf
COPY ./storage-schemas.conf /var/lib/graphite/conf/storage-schemas.conf

RUN echo "SECRET_KEY='`python -c 'import os; import base64; print(base64.b64encode(os.urandom(40)))'`'" >> /var/lib/graphite/webapp/graphite/local_settings.py

# Configure collectd
COPY ./collectd.conf /etc/collectd/collectd.conf
COPY ./collectd-graphite.conf /etc/collectd/collectd.conf.d/collectd-graphite.conf

# Configure grafana
COPY ./config.js /var/lib/grafana/config.js

VOLUME  /var/log/supervisor
VOLUME  /data

# ---------------- #
# Setup runscript  #
# ---------------- #
COPY ./monitor-run /
RUN chmod 755 /monitor-run

# ---------------- #
# Expose Ports     #
# ---------------- #

# Grafana
EXPOSE   80
# Graphite carbon/plaintext, carbon/pickle, carbon/query cache
EXPOSE 2003 2004 7002
# Collectd UDP socket
EXPOSE 25826/udp
# Stats UDP Socket
EXPOSE 8125/udp

# ------------------ #
#     Entrypoint     #
# ------------------ #

ENTRYPOINT \
  ["/monitor-run"]

# docker build [--rm] -t <user>/monitor .
# docker run -v /data --name monitor-data busybox:ubuntu-14.04
# docker run -d -v /etc/localtime:/etc/localtime:ro --volumes-from monitor-data -p 80:80 -p 2003:2003 -p 2004:2004 -p 7002:7002 -p 8125:8125/udp -p 25826:25826/udp --name monitor <user>/monitor
