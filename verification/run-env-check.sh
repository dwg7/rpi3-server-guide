#!/usr/bin/env bash
# Runs INSIDE an ubuntu:24.04 container. Question: when the MapServer configuration file is NOT at the default
# /etc/mapserver.conf, which Apache settings really deliver MAPSERVER_CONFIG_FILE to MapServer, under CGI and under FastCGI?
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq apache2 libapache2-mod-fcgid cgi-mapserver mapserver-bin gdal-bin python3 curl >/dev/null 2>&1
grep PRETTY_NAME /etc/os-release; dpkg -l cgi-mapserver libapache2-mod-fcgid apache2 2>/dev/null | awk '/^ii/{print $2, $3}'
mkdir -p /work && cd /work && python3 /scripts/extract.py /guide/index.html /work/x >/dev/null
python3 x/make_points.py >/dev/null && ogr2ogr -f "ESRI Shapefile" points.shp points.geojson
mkdir -p /srv/data /srv/mapfiles && cp points.shp points.shx points.dbf points.prj /srv/data/ && cp x/demo.map /srv/mapfiles/
# the configuration file lives in a NON-default place; nothing at /etc/mapserver.conf
cp x/mapserver.conf /srv/custom.conf; rm -f /etc/mapserver.conf
a2enmod cgid fcgid >/dev/null 2>&1
ln -sf /usr/lib/cgi-bin/mapserv /usr/lib/cgi-bin/mapserv.fcgi
cat > /etc/apache2/conf-available/fcgi-handler.conf <<'CONF'
<Directory /usr/lib/cgi-bin>
  Options +ExecCGI
  AddHandler fcgid-script .fcgi
</Directory>
CONF
a2enconf fcgi-handler >/dev/null 2>&1
Q='map=/srv/mapfiles/demo.map&SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap&LAYERS=points&STYLES=&SRS=EPSG:4326&BBOX=-10,-10,10,10&WIDTH=256&HEIGHT=256&FORMAT=image/png'
wait_up() { for i in $(seq 1 20); do [ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)" != 000 ] && return 0; sleep 0.5; done; echo "apache did not come up" >&2; }
hard_stop() { apache2ctl stop >/dev/null 2>&1; pkill apache2 2>/dev/null; for i in $(seq 1 20); do pgrep apache2 >/dev/null || break; sleep 0.5; done; rm -f /var/run/apache2/apache2.pid; pkill -f mapserv.fcgi 2>/dev/null; sleep 1; }
reset() {
  hard_stop
  rm -f /etc/apache2/conf-enabled/envtest.conf /etc/apache2/conf-available/envtest.conf
  sed -i '/MAPSERVER_CONFIG_FILE/d' /etc/apache2/envvars
}
probe() {  # $1 = label, $2 = apache snippet ("" for none), $3 = envvars line ("" for none)
  reset
  [ -n "$2" ] && { printf '%s\n' "$2" > /etc/apache2/conf-available/envtest.conf; a2enconf envtest >/dev/null 2>&1; }
  [ -n "$3" ] && echo "$3" >> /etc/apache2/envvars
  apache2ctl start >/dev/null 2>&1; wait_up
  r1=$(curl -s -o /dev/null -w "%{content_type}" "http://localhost/cgi-bin/mapserv?$Q")
  r2=$(curl -s -o /dev/null -w "%{content_type}" "http://localhost/cgi-bin/mapserv.fcgi?$Q")
  ok() { case "$1" in image/png) echo "works";; *) echo "FAILS";; esac; }
  printf "%-62s CGI: %-6s FastCGI: %s\n" "$1" "$(ok $r1)" "$(ok $r2)"
}
probe_direct() {  # $1 = label, $2 = apache snippet, $3 = "env" to put the variable in Apache's own environment
  reset
  [ -n "$2" ] && { printf '%s\n' "$2" > /etc/apache2/conf-available/envtest.conf; a2enconf envtest >/dev/null 2>&1; }
  ( set -a; . /etc/apache2/envvars; set +a
    if [ "$3" = env ]; then MAPSERVER_CONFIG_FILE=/srv/custom.conf /usr/sbin/apache2 -k start; else /usr/sbin/apache2 -k start; fi ) >/dev/null 2>&1
  wait_up
  r1=$(curl -s -o /dev/null -w "%{content_type}" "http://localhost/cgi-bin/mapserv?$Q")
  r2=$(curl -s -o /dev/null -w "%{content_type}" "http://localhost/cgi-bin/mapserv.fcgi?$Q")
  ok() { case "$1" in image/png) echo "works";; *) echo "FAILS";; esac; }
  printf "%-62s CGI: %-6s FastCGI: %s\n" "$1" "$(ok $r1)" "$(ok $r2)"
  pkill apache2 2>/dev/null; sleep 1; pkill -f mapserv.fcgi 2>/dev/null
}
echo "config file at /srv/custom.conf (not the default place). Does the request reach MapServer's config?"
probe "S0 nothing set (control)" "" ""
probe "S1 SetEnv (the guide's plain-CGI line)" "SetEnv MAPSERVER_CONFIG_FILE /srv/custom.conf" ""
probe "S2 FcgidInitialEnv (the guide's FastCGI line)" "FcgidInitialEnv MAPSERVER_CONFIG_FILE /srv/custom.conf" ""
probe "S3 apache2ctl start (as Ubuntu's service does) + env in envvars + PassEnv" "PassEnv MAPSERVER_CONFIG_FILE" "export MAPSERVER_CONFIG_FILE=/srv/custom.conf"
probe "S4 apache2ctl start + env in envvars only" "" "export MAPSERVER_CONFIG_FILE=/srv/custom.conf"
echo "--- control: the configuration file at the DEFAULT place /etc/mapserver.conf, nothing else set"
cp /srv/custom.conf /etc/mapserver.conf
probe "S7 file at /etc/mapserver.conf, nothing else set" "" ""
rm -f /etc/mapserver.conf
echo "--- Apache started directly, keeping the container's environment (like a container's foreground start):"
probe_direct "S5 variable in Apache's own environment + PassEnv" "PassEnv MAPSERVER_CONFIG_FILE" env
probe_direct "S6 variable in Apache's own environment only" "" env
echo "=== DONE ==="
