#!/usr/bin/env bash
# Runs INSIDE an ubuntu:24.04 container (see README.md). Runs the MapServer steps exactly as the guide's page gives them.
export DEBIAN_FRONTEND=noninteractive
sec() { echo; echo "=== $* ==="; }
# a container has no sudo and no systemd: small stand-ins so the page's commands run unchanged
sudo() { "$@"; }
systemctl() { [ "$1" = reload ] && { apache2ctl graceful >/dev/null 2>&1 || apache2ctl start >/dev/null 2>&1; }; return 0; }
export -f sudo systemctl

sec "environment"
grep -E '^PRETTY_NAME' /etc/os-release; uname -m
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq apache2 libapache2-mod-fcgid cgi-mapserver mapserver-bin gdal-bin python3 curl file procps >/dev/null 2>&1
echo "apt rc=$?"
a2enmod fcgid >/dev/null 2>&1    # the guide's 4.1 command, minus the apt line already run above
mkdir -p /work && cd /work && python3 /scripts/extract.py /guide/index.html /work/x
sec "4.1 checks"
bash /work/x/cmd-ms-version.sh 2>&1
sec "5.1 data (page's own commands)"
mkdir -p /opt/geoserver/data_dir
cp /work/x/make_points.py . && bash /work/x/cmd-data.sh 2>&1 | tail -4
mkdir -p /srv/mapfiles && cp /work/x/demo.map /srv/mapfiles/demo.map && cp /work/x/mapserver.conf /etc/mapserver.conf
sec "4.2 error table: what each situation really gives"
Q="QUERY_STRING=map=/srv/mapfiles/demo.map&SERVICE=WMS&REQUEST=GetCapabilities"
M=/usr/lib/cgi-bin/mapserv
one() { grep -o -E 'msLoadConfig[^<]*|msCGILoadMap[^<]*|<WMS_Capabilities' | head -1; }
mv /etc/mapserver.conf /etc/mapserver.conf.bak
echo "no file anywhere:                       $($M -nh "$Q" 2>&1 | one)"
mv /etc/mapserver.conf.bak /etc/mapserver.conf
echo "file at /etc/mapserver.conf, no env:    $($M -nh "$Q" 2>&1 | one)"
mv /etc/mapserver.conf /srv/custom.conf
echo "file elsewhere, env not set:            $($M -nh "$Q" 2>&1 | one)"
echo "file elsewhere, env set:                $(MAPSERVER_CONFIG_FILE=/srv/custom.conf $M -nh "$Q" 2>&1 | one)"
mv /srv/custom.conf /etc/mapserver.conf
cp /srv/mapfiles/demo.map /tmp/other.map
echo "path outside MS_MAP_PATTERN:            $($M -nh "QUERY_STRING=map=/tmp/other.map&SERVICE=WMS&REQUEST=GetCapabilities" 2>&1 | one)"
sec "4.3 step 1 (page's command)"
bash /work/x/cmd-ms-standalone.sh 2>&1 | head -3 | cut -c1-120
echo "layer 'points' named in capabilities: $(MAPSERVER_CONFIG_FILE=/etc/mapserver.conf $M -nh "$Q" | grep -c '<Name>points</Name>')"
sec "4.3 step 2 (Apache, plain CGI; page's commands + conf)"
cp /work/x/apache-plain.conf /etc/apache2/conf-available/mapserver.conf
bash /work/x/cmd-apache-plain.sh 2>&1 | grep -v AH00558
URL=$(cat /work/x/url-ms-getmap.txt)
sleep 1
echo "--- step 3: GetMap through Apache"
curl -s -o /work/cgi.png -w "%{http_code} %{content_type} %{size_download}\n" "$URL"; file /work/cgi.png | cut -c1-90
echo "--- bench.py, plain CGI (x3)"
for i in 1 2 3; do python3 /work/x/bench.py "$URL"; done
sec "4.4 FastCGI (page's conf + commands)"
cp /work/x/apache-fcgi.conf /etc/apache2/conf-available/mapserver-fcgi.conf
bash /work/x/cmd-apache-fcgi.sh 2>&1 | grep -v AH00558
sleep 1
FURL="${URL/mapserv?/mapserv.fcgi?}"
curl -s -o /work/fcgi.png -w "%{http_code} %{content_type} %{size_download}\n" "$FURL"; file /work/fcgi.png | cut -c1-90
echo "--- bench.py, FastCGI (x3)"
for i in 1 2 3; do python3 /work/x/bench.py "$FURL"; done
echo "--- processes after load (page's command):"
bash /work/x/cmd-ps.sh
echo; echo "=== DONE ==="
