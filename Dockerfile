FROM debian:jessie

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update

RUN apt-get install -y --force-yes locales
RUN echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
RUN echo "LANG=\"fr_FR.UTF-8\"" >> /etc/environment
RUN dpkg-reconfigure locales

ENV LC_ALL   fr_FR.UTF-8
ENV LANG     fr_FR.UTF-8
ENV LANGUAGE fr_FR.UTF-8

# Configure timezone
RUN echo "Europe/Paris" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# -------------------- #
#     Installation     #
# -------------------- #

# install carbon & graphite
RUN apt-get install -y wget \
    supervisor nginx-light collectd \
    build-essential python-pip python-dev \
    libcairo2-dev libffi-dev git python-yaml sudo
RUN pip install 'Twisted==14.0.0' Django==1.5.12 python-memcached==1.47 txAMQP==0.4 simplejson==2.1.6 bucky==2.3.0 django-tagging==0.3.6 && \
    pip install pyparsing==1.5.7 cairocffi==0.7.2 whitenoise pytz gunicorn
RUN pip install git+git://github.com/graphite-project/whisper.git#egg=whisper git+git://github.com/graphite-project/ceres.git#egg=ceres
RUN pip install --install-option="--prefix=/var/lib/graphite" --install-option="--install-lib=/var/lib/graphite/lib" carbon && \
    pip install --install-option="--prefix=/var/lib/graphite" --install-option="--install-lib=/var/lib/graphite/webapp" graphite-web==0.9.14
RUN adduser --system --group --no-create-home collectd

# grafana
RUN mkdir /var/lib/grafana && cd /var/lib/grafana && \
    wget -nv https://grafanarel.s3.amazonaws.com/builds/grafana-2.5.0.linux-x64.tar.gz -O grafana.tar.gz && \
    tar zxf grafana.tar.gz --strip-components=1 && \
    rm -rf grafana.tar.gz

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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
RUN chown -R www-data:www-data /var/lib/graphite/webapp

RUN echo "SECRET_KEY='`python -c 'import os; import base64; print(base64.b64encode(os.urandom(40)))'`'" >> /var/lib/graphite/webapp/graphite/local_settings.py

# Configure collectd
COPY ./collectd.conf /etc/collectd/collectd.conf
COPY ./collectd-graphite.conf /etc/collectd/collectd.conf.d/collectd-graphite.conf

# Configure grafana
COPY ./grafana/config.ini /etc/grafana/config.ini

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
