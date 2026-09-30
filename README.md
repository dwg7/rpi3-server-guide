# rpi3-server-guide

Hands-on guide for running GeoServer and MapServer on a Raspberry Pi 3 (1 GB): setup, benchmarks, known pitfalls, and a space for collaborators' findings.

**Read the guide: <https://dwg7.unopengis.org/rpi3-server-guide/>**

The guide is a single static HTML page ([`index.html`](index.html)). It is meant to sit on a workbench while you type commands, so it is one long page with anchor links rather than a multi-page site.

## What it covers

1. Introduction
2. Preparing the Pi (Ubuntu Server 64-bit)
3. GeoServer setup, with notes for 1 GB of RAM
4. MapServer setup (FastCGI, and the `MS_MAP_PATTERN` trap)
5. A reproducible benchmark procedure
6. Known pitfalls
7. A space for collaborators' findings

Most measurements come from a Raspberry Pi 4B (4 GB). Anything not yet verified on a Pi 3 is marked as such in the guide.

## How this guide grows

This is a work in progress that is written together with the people who try it. Findings from real Pi 3 boards are added to the page as they arrive.

You do not need a GitHub account to contribute. Collaborators send their observations by email, and the maintainers add them to the page, crediting each person in the form they prefer (full name, handle, or no mention). Issues and pull requests are also welcome from anyone who would rather use GitHub.

## Design notes

Decisions about how the guide is built are recorded in [`docs/decisions/`](docs/decisions/):

- [0001](docs/decisions/0001-single-page.md): a single long HTML page
- [0002](docs/decisions/0002-no-framework.md): no framework and no build step
- [0003](docs/decisions/0003-pages-from-root.md): published from the repository root with GitHub Pages

## License

[CC0 1.0 Universal](LICENSE).
