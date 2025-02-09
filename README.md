# Home Server Configs

### Description:
This repo holds some of the basic files I use for my home server. Currently this includes monitoring setup (Grafana, Prometheus & Node Exporter) plus an installation script for Nextcloud.

### Usage
To setup the monitoring system, `git clone` this repo onto your server device, cd in the main folder, then (assuming you have Docker installed and setup) run `docker compose up -d`. You should now be able to access the Grafana dashboard on your `localhost:3000` or remotely if you have this setup (here is another plug for using [Tailscale](https://www.tailscale.com) to manager your local devices). Per the TODO comment below, this will eventually become part of the install script.

EXPERIMENTAL: to use the install script you should only need to run `chmod -x installHomeLabn.sh` then `./installHomeLab.sh`. As of this commit the script is untested and should not be used unless you are comfortable with debugging and cleaning up if necessary. Currently the list of services to install (though you can decide which ones you want) are:
- Tailscale (mesh VPN built on WireGuard)
- Docker (containers for some services)
- Jellyfin (media service)
- Immich (photo backup app)
- Nextcloud (file transfer/backup service)
- Home Assistant (home automation platform)
- TODO: make the monitoring setup part of this script

When this is completely functional and properly tested I will remove this note and leave the instructions for how to use it.

Happy home labbing!