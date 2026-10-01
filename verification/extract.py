#!/usr/bin/env python3
"""Pull the command blocks out of the guide's index.html, so the checks run exactly what the page says.
usage: extract.py <index.html> <outdir>"""
import re, html, sys, os
s = open(sys.argv[1], encoding="utf-8").read()
out = sys.argv[2]; os.makedirs(out, exist_ok=True)
pre = [html.unescape(m) for m in re.findall(r"<pre><code>(.*?)</code></pre>", s, re.S)]
picks = {
    "make_points.py":  lambda p: p.startswith('#!/usr/bin/env python3\n"""Write 5,000'),
    "bench.py":        lambda p: p.startswith('#!/usr/bin/env python3\n"""4 workers'),
    "demo.map":        lambda p: p.startswith("MAP\n"),
    "mapserver.conf":  lambda p: p.startswith("# /etc/mapserver.conf"),
    "apache-plain.conf": lambda p: p.strip() == "SetEnv MAPSERVER_CONFIG_FILE /etc/mapserver.conf",
    "apache-fcgi.conf": lambda p: p.startswith("# /etc/apache2/conf-available/mapserver-fcgi.conf"),
    "cmd-gs-install.sh": lambda p: p.startswith("export GEOSERVER_VERSION=3.0.1"),
    "cmd-data.sh":     lambda p: p.startswith("python3 make_points.py\nogr2ogr"),
    "cmd-ms-version.sh": lambda p: p.startswith("mapserv -v | cut"),
    "cmd-ms-standalone.sh": lambda p: p.startswith("MAPSERVER_CONFIG_FILE=/etc/mapserver.conf /usr/lib/cgi-bin/mapserv -nh"),
    "cmd-apache-plain.sh": lambda p: p.startswith("sudo a2enmod cgid"),
    "cmd-apache-fcgi.sh": lambda p: p.startswith("sudo ln -s /usr/lib/cgi-bin/mapserv"),
    "cmd-ps.sh":       lambda p: p.startswith("ps -eo pid,rss,args | grep mapserv.fcgi"),
    "url-ms-getmap.txt": lambda p: p.startswith("http://localhost/cgi-bin/mapserv?map="),
    "cmd-bench-gs.sh": lambda p: p.startswith('python3 bench.py "http://localhost:8080/geoserver/wms'),
}
for name, pred in picks.items():
    hit = next((p for p in pre if pred(p)), None)
    if hit is None: print("MISSING", name); continue
    open(os.path.join(out, name), "w").write(hit.rstrip("\n") + "\n"); print("extracted", name)
