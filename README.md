# ns8-pihole

Pi-hole is a network-level ad blocker that works by intercepting DNS requests on your network. It blocks ads and unwanted content by filtering out requests to known ad-serving domains, enhancing browsing speed and security for all devices connected to the network.

To use Pi-hole effectively, it must be set as the DNS server for all devices on your network. You can do this in one of two ways:

- Configure the DHCP Server: Set your router's DHCP settings to automatically assign NethServer 8's IP address as the DNS server for all devices. This method is simple and ensures that all devices use Pi-hole without needing manual configuration.

- Manual Configuration: Manually set the DNS server on each device to NethServer 8's IP address. This allows for fine-grained control but is more time-consuming and less consistent across multiple devices.

Using the DHCP server to assign Pi-hole as the DNS is generally the easiest and most reliable approach. Hovewer the Pi-hole's DHCP feature is disabled, you must rely on an external DHCP server, typically your router, to assign network settings to your devices. This means you need to configure the external DHCP server to assign Pi-hole as the DNS server to all devices on your network. Without this configuration, Pi-hole won't be used for DNS queries, and its ad-blocking features won't be effective.

## Install

Instantiate the module with:

    add-module ghcr.io/nethserver/pihole:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "pihole1", "image_name": "pihole", "image_url": "ghcr.io/nethserver/pihole:latest"}

## Configure

Let's assume that the mattermost instance is named `pihole1`.

Launch `configure-module`, by setting the following parameters:
- `host`: a fully qualified domain name for the application
- `http2https`: enable or disable HTTP to HTTPS redirection (true/false)
- `lets_encrypt`: enable or disable Let's Encrypt certificate (true/false)


Example:

```
api-cli run configure-module --agent module/pihole1 --data - <<EOF
{
  "host": "pihole.domain.com",
  "http2https": true,
  "lets_encrypt": false
}
EOF
```

The above command will:
- start and configure the pihole instance
- configure a virtual host for trafik to access the instance

## Get the configuration
You can retrieve the configuration with

```
api-cli run get-configuration --agent module/pihole1
```

## test to query DNS

once pihole is configured, up and running you can test by querying the pihole from the IP of the server

```
while true; do
    nslookup adservice.google.com 192.168.100.243
done
```

- known hostname and redirected to 0.0.0.0 or ::
adservice.google.com
stats.wp.com

## Uninstall

To uninstall the instance:

    remove-module --no-preserve pihole1

## Smarthost setting discovery

Some configuration settings, like the smarthost setup, are not part of the
`configure-module` action input: they are discovered by looking at some
Redis keys.  To ensure the module is always up-to-date with the
centralized [smarthost
setup](https://nethserver.github.io/ns8-core/core/smarthost/) every time
pihole starts, the command `bin/discover-smarthost` runs and refreshes
the `state/smarthost.env` file with fresh values from Redis.

Furthermore if smarthost setup is changed when pihole is already
running, the event handler `events/smarthost-changed/10reload_services`
restarts the main module service.

See also the `systemd/user/pihole.service` file.

This setting discovery is just an example to understand how the module is
expected to work: it can be rewritten or discarded completely.

## Debug

some CLI are needed to debug

- The module runs under an agent that initiate a lot of environment variables (in /home/pihole1/.config/state), it could be nice to verify them
on the root terminal

    `runagent -m pihole1 env`

- you can become runagent for testing scripts and initiate all environment variables
  
    `runagent -m pihole1`

 the path become : 
```
    echo $PATH
    /home/pihole1/.config/bin:/usr/local/agent/pyenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/
```

- if you want to debug a container or see environment inside
 `runagent -m pihole1`
 ```
podman ps
```

you can see what environment variable is inside the container
```
podman exec  pihole-app env
```

you can run a shell inside the container

```
podman exec -ti   pihole-app sh
/ # 
```
## Testing

Test the module using the `test-module.sh` script:


    ./test-module.sh <NODE_ADDR> ghcr.io/nethserver/pihole:latest

The tests are made using [Robot Framework](https://robotframework.org/)

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org]((https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project
