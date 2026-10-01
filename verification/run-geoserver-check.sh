#!/usr/bin/env bash
# Runs INSIDE an ubuntu:24.04 container started with a 1 GB memory limit (see README.md).
export DEBIAN_FRONTEND=noninteractive
sec() { echo; echo "=== $* ==="; }
sudo() { "$@"; }; export -f sudo
export USER=root
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq openjdk-17-jre-headless unzip curl gdal-bin python3 file iproute2 >/dev/null 2>&1
echo "apt rc=$?"; java -version 2>&1 | head -1; grep PRETTY_NAME /etc/os-release
echo "cgroup memory limit: $(( $(cat /sys/fs/cgroup/memory.max)/1048576 )) MB"
mkdir -p /work && cd /work && python3 /scripts/extract.py /guide/index.html /work/x >/dev/null

sec "3.1 page's own commands (download, unpack, chown)"
( time bash /work/x/cmd-gs-install.sh ) 2>&1 | grep -E "real|rror" ; ls -l geoserver-3.0.1-bin.zip | awk '{print $5, "bytes"}'
echo "--- the check the page gives:"; find /opt/geoserver -maxdepth 3 -name start.jar -print
echo "--- archive top level (is there a version-numbered folder?)"
unzip -l geoserver-3.0.1-bin.zip | awk 'NR>3{print $4}' | cut -d/ -f1 | sort | uniq -c | sort -rn | head -8

sec "3.2 start with the page's java arguments, then the page's checks"
export GEOSERVER_HOME=/opt/geoserver GEOSERVER_DATA_DIR=/opt/geoserver/data_dir
cd /opt/geoserver
nohup /usr/bin/java -Xms256m -Xmx512m -Djetty.http.host=127.0.0.1 -DGEOSERVER_DATA_DIR=${GEOSERVER_DATA_DIR} -jar /opt/geoserver/start.jar > /root/geoserver.log 2>&1 &
T0=$(date +%s)
for i in $(seq 1 90); do c=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/geoserver/web/ 2>/dev/null); [ "$c" != 000 ] && { echo "first answer after $(( $(date +%s)-T0 ))s: HTTP $c"; break; }; sleep 4; done
curl -sI http://localhost:8080/geoserver/web/ | head -1
ss -tlnp | grep 8080 | awk '{print $4}'
echo "java resident memory after start: $(ps -o rss= -C java | awk '{printf "%d MB", $1/1024}')"

sec "5.1 data (page's commands) and layer (REST equivalent of the menu steps)"
cd /work && cp x/make_points.py . && mkdir -p /srv/data && bash x/cmd-data.sh 2>&1 | tail -3
A="-u admin:geoserver"; H="Content-Type: text/xml"; G=http://localhost:8080/geoserver/rest
curl -s $A -o /dev/null -w "workspace %{http_code}; " -XPOST -H "$H" -d '<workspace><name>demo</name></workspace>' $G/workspaces
curl -s $A -o /dev/null -w "namespace %{http_code}; " -XPUT -H "$H" -d '<namespace><prefix>demo</prefix><uri>http://example.org/demo</uri></namespace>' $G/namespaces/demo
curl -s $A -o /dev/null -w "store %{http_code}; " -XPOST -H "$H" -d '<dataStore><name>points</name><connectionParameters><entry key="url">file:data/points.shp</entry><entry key="namespace">http://example.org/demo</entry></connectionParameters></dataStore>' $G/workspaces/demo/datastores
curl -s $A -o /dev/null -w "publish %{http_code}\n" -XPOST -H "$H" -d '<featureType><name>points</name></featureType>' $G/workspaces/demo/datastores/points/featuretypes
curl -s $A -H "Accept: application/json" $G/workspaces/demo/datastores/points/featuretypes/points | python3 -c "import sys,json; d=json.load(sys.stdin)['featureType']; print('SRS found by GeoServer:', d.get('srs'), '| bbox', d['nativeBoundingBox']['minx'], d['nativeBoundingBox']['maxx'])"

sec "5.3 the page's own GetMap call, then bench.py (x3)"
CMD=$(cat x/cmd-bench-gs.sh); URL=$(echo "$CMD" | sed -E 's/^python3 bench.py "(.*)"$/\1/')
curl -s -o gs.png -w "%{http_code} %{content_type} %{size_download} bytes\n" "$URL"; file gs.png | cut -c1-80
W='http://localhost:8080/geoserver/demo/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames=demo:points&count=500'
echo "--- cold start (page 3.4): 1st GML / 2nd GML / GeoJSON request"
for u in "$W" "$W" "$W&outputFormat=application/json"; do curl -s -o /dev/null -w "%{time_total}s  " "$u"; done; echo
cp x/bench.py . && for i in 1 2 3; do bash x/cmd-bench-gs.sh; done
echo "java resident memory after load: $(ps -o rss= -C java | awk '{printf "%d MB", $1/1024}')"
echo "out-of-memory kills: $(grep oom_kill /sys/fs/cgroup/memory.events)"
echo "ERROR lines in geoserver.log: $(grep -c ' ERROR ' /root/geoserver.log)"
echo; echo "=== DONE ==="
