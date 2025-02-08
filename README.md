# Home Server Configs

### Description:
This repo holds some of the basic files I use for my home server. Currently this includes monitoring setup (Grafana, Prometheus & Node Exporter) plus an installation script for Nextcloud.

### Usage
To setup the monitoring system, `git clone` this repo onto your server device, cd in the main folder, then (assuming you have Docker installed and setup) run `docker compose up -d`. You should now be able to access the Grafana dashboard on your `localhost:3000` or remotely if you have this setup (here is another plug for using [Tailscale](https://www.tailscale.com) to manager your local devices).

EXPERIMENTAL: to use the install script you should only need to run `chmod -x installNextcloud.sh` then `./instasllNextcloud.sh`. As of this commit the script is untested and should not be used unless you are comfortable with debugging and cleaning up if necessary. When this is completely functional and properly tested I will remove this note and leave the instructions for how to use it.

Happy home labbing!