# Monitor

Graphite monitoring and reporting with dedicated volume for data storage.

* `docker build [--rm] -t <user>/monitor .`
* `docker run -v /data --name monitor-data busybox:ubuntu-14.04`
* `docker run -d -h <hostname> -v /etc/localtime:/etc/localtime:ro --volumes-from monitor-data -p 80:80 -p 2003:2003 -p 2004:2004 -p 7002:7002 -p 8125:8125/udp -p 25826:25826/udp --name monitor <user>/monitor`

## Software

* Based on debian:jessie box.
* whisper, ceres, carbon, graphite installed via pip.
* Built with grafana 2.5.0

## Usage
Carbon default metrics configuration is to receive metrics every 10s.

Connect to grafana with url http://localhost/grafana.
Configure grafana with graphite datasource : http://localhost:8000 with proxy mode.

Ports

* 80   grafana & graphite
* 2003 carbon / plaintext
* 2004 carbon / pickle
* 7002 carbon query port for graphite-web
* 25826 Collectd UDP port handled by bucky
* 8125 Statsd UDP port handled by bucky

