# Container check of the guide

On 2026-10-01 the commands and settings in the guide were run in a container, to find mistakes in them before a collaborator meets them.
It shows that the **steps are correct**. It says **nothing about speed or memory on a real Raspberry Pi**: the container ran on a desktop-class computer (Docker, 8 CPUs, `linux/arm64`, Ubuntu 24.04.5).

The scripts do not copy the guide's commands. `extract.py` pulls them out of `index.html`, so the checks run exactly what the page says. (A container has no `sudo` and no systemd, so the scripts define a stand-in for `sudo`, and for `systemctl reload`. The GeoServer service file itself was therefore not run; the same `java` command line was started directly.)

| File | What it does |
|---|---|
| `extract.py` | Pulls the command blocks and settings out of `index.html`. |
| `run-mapserver-check.sh` | Section 4 and the data part of 5.1: MapServer packages, the configuration-file behaviour (4.2), a first map with plain CGI (4.3), FastCGI (4.4), and the benchmark script. |
| `run-geoserver-check.sh` | Section 3 and 5.1: download and unpack GeoServer 3.0.1 (3.1), start it with the guide's Java arguments in a 1 GB container (3.2), publish the test layer through GeoServer's REST interface, and run the benchmark script. |
| `run-env-check.sh` | Which Apache setting delivers `MAPSERVER_CONFIG_FILE` to MapServer when the file is not at `/etc/mapserver.conf` (plain CGI and FastCGI). Run on Ubuntu 24.04 (MapServer 8.0.1) and Debian 13 trixie (8.4.0). Results are in section 4.2 of the guide. |
| `logs/` | The raw output of the latest runs. |

## Run it yourself

From the root of the repository (needs Docker; the GeoServer check downloads about 127 MB):

```bash
docker run --rm --platform linux/arm64 -v "$PWD":/guide:ro -v "$PWD/verification":/scripts:ro \
  ubuntu:24.04 bash /scripts/run-mapserver-check.sh

# the environment-variable check also needs curl and python3 (on a plain debian:trixie-slim image, install them first)
docker run --rm --platform linux/arm64 -v "$PWD":/guide:ro -v "$PWD/verification":/scripts:ro \
  ubuntu:24.04 bash -c 'apt-get update -qq; apt-get install -y -qq curl python3 >/dev/null; bash /scripts/run-env-check.sh'

docker run --rm --platform linux/arm64 --memory=1g --memory-swap=1g -v "$PWD":/guide:ro -v "$PWD/verification":/scripts:ro \
  ubuntu:24.04 bash /scripts/run-geoserver-check.sh
```

## What was not checked

- Anything on a Raspberry Pi 3 (or any Pi). Throughput and memory figures in the logs mean nothing for a Pi.
- The GeoServer menu steps in section 5.1. The layer was made through the REST interface with the same settings instead.
- The systemd service file, Raspberry Pi Imager and cloud-init (section 2), and the Apache settings on a real network.
