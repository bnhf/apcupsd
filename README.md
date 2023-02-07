This is a simple Ubuntu base with <code>apcupsd</code> installed. It manages and monitors a USB Connected UPS Device, and has the ability to gracefully shut down the host computer in the event of a prolonged power outage.  This is done with no customisation to the host whatsoever, there's no need for cron jobs on the host, or trigger files and scripts.  Everything is done within the container.

<b>Use Cases :</b><br>
Use this image if your UPS is connected to your docker host by USB Cable and you don't want to run <code>apcupsd</code> in the physical host OS.

Equally, this container can be run on any other host to monitor another instance of this container running on a host connected to the UPS for power status messages from the UPS, and take action to gracefully shut down the non-UPS connected host.

The purpose of this image is to containerise the APC UPS monitoring daemon so that it is separated from the OS, yet still has access to the UPS via USB Cable.  

It is not necessary to run this container in <code>privileged</code> mode.  Instead, we attach only the specific USB Device to the container using the <code>--device</code> directive in the <code>docker run</code> command.  However if you want the container to shut down the host when UPS battery power is critically low, then it is necessary to run the container in privileged mode and also expose the dbus socket responsible for triggering system shutdown, from the host to this container. See below in the Configuration section.

Other apcupsd images i've seen are for exporting monitoring data to grafana or prometheus, this image does not do that, though it does expose port 3551 to the network allowing for the apcupsd monitorig data to be captured using those other containers to handle flow of data into your preferred monitoring solution. Persoanlly, I use collectd to extract data from the apcupsd container, graphite capture the data and grafana to present pretty pictures.


<b>Configuration :</b>

Very little configuration is currently required for this image to work, though you may be required to tweak the USB device that is passed through to your container by docker.

It is recommended to create a <code>volume</code> before creating the container, this will allow for your configuration files to persist rebuilds and updates of teh container.  This can be done as follows from the command line, or via Portainer etc.   

You can leave the volume empty, the container will fill put default versions of the configuration files and scripts for apcupsd when the container is created.  These will not be overwritten if the container is removed and recreated, so if you want to make any customisations, make them here. You can customise them either from from within the container, or from the host.  Restart or redeploy the container to apply any changed settings.

```
docker volume create apcupsd_config
```

Then create the container with the following command.

```
docker run -d --privileged \
  --name=apcupsd  \
  -e TZ=US/Mountain \
  --device=/dev/usb/hiddev0 \
  --restart unless-stopped \
  -p=3551:3551 \
  -v /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
  -v /data/apcupsd:/etc/apcupsd
  bnhf/apcupsd:latest
```

And, for those using tools with docker-compose, here's an example:

```yml
version: '3.7'
services:
  apcupsd:
    image: bnhf/apcupsd:latest
    container_name: apcupsd
    devices:
      - /dev/usb/hiddev0 # This device needs to match what the APC UPS on your APCUPSD_MASTER system uses -- Comment out this section on APCUPSD_SLAVES
    ports:
      - 3551:3551
    environment:
      - UPSNAME=${UPSNAME} # Sets a name for the UPS (1 to 8 chars), that will be used by System Tray notifications, apcupsd-cgi and Grafana dashboards
#      - UPSCABLE=${UPSCABLE} # Usually doesn't need to be changed on system connected to UPS. (default=usb) On APCUPSD_SLAVES set the value to ether
#      - UPSTYPE=${UPSTYPE} # Usually doesn't need to be changed on system connected to UPS. (default=usb) On APCUPSD_SLAVES set the value to net
#      - DEVICE=${DEVICE} # Use this only on APCUPSD_SLAVES to set the hostname or IP address of the APCUPSD_MASTER with the listening port (:3551)
#      - POLLTIME=${POLLTIME} # Interval (in seconds) at which apcupsd polls the UPS for status (default=60)
      - ONBATTERYDELAY=${ONBATTERYDELAY} # Sets the time in seconds from when a power failure is detected until an onbattery event is initiated (default=6)
      - BATTERYLEVEL=${BATTERYLEVEL} # Sets the daemon to send the poweroff signal when the UPS reports a battery level of x% or less (default=5)
      - MINUTES=${MINUTES} # Sets the daemon to send the poweroff signal when the UPS has x minutes or less remaining power (default=5)
      - TIMEOUT=${TIMEOUT} # Sets the daemon to send the poweroff signal when the UPS has been ON battery power for x seconds (default=0)
      - SELFTEST=${SELFTEST} # Sets the daemon to ask the UPS to perform a self test every x hours (default=336)
#      - APCUPSD_SLAVES=${APCUPSD_SLAVES} # If this is the APCUPSD_MASTER, then enter the APUPSD_SLAVES list here (space separated)
      - TZ=${TZ}
    volumes:
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket # Required to support host shutdown from the container
      - /data/apcupsd:/etc/apcupsd # /etc/apcupsd can be bound to a directory or a docker volume
    restart: unless-stopped
# volumes: # Use this section for volume bindings only
#   config: # The name of the stack will be appended to the beginning of this volume name, if the volume doesn't already exist
#     external: true # Use this directive if you created the docker volume in advance
```
Environment variables can be hardcoded into the above docker-compose, or added in the environment section of tool like Portainer. 

As I mentioned above, you will likely want to customise <code>/etc/apcupsd/apcupsd.conf</code> for each of the hosts that you run this container on, so it will need to be bind mounded for persistence purpoes.  I recommend setting the threshold for shutting down hosts not directly connected to the UPS a little higher than the host connected to the UPS, so that the remote hosts are able to shut down before the UPS Connected host is no longer available to provide signalling.

<b>Notes</b><br>
<ul type="disc">
<li>In case you're interested, I discovered that (at least my Smart UPS 3000) reports itself over USB as a <code>usbhid</code> device.  I discovered this by running <code>usb-devices</code> at the linux command line on the physical host that is connected to the UPS by USB, which told me the device type.  Looking in <code>/dev/usb/</code> I only had two to choose from, so I was able to hit on the correct one pretty quickly. This does not seem to change dunamically at boot, though I've not checked yet to see if it changes if I plug the USB Cable into a different port.</li>
<li>Testing was done by running the <code>apcaccess</code> on the physical host, and in the container, though you likely only need to run it in the container, after all, we don't want the APC UPS software installed in the host, that's the point of this image after all.  If the test is successful, then the output from <code>apcaccess</code> is quite a bit different compared with a fail scenario.  The difference should be self explanatory. This lets us know that the <code>apcupsd</code> daemon successfully connected to the UPS over the USB cable.  If all is well, port 3551 should also be exposed to the network allowing other systems to take a heartbeat signal from the UPS via this container.</li>
<li>You may wish to customise the <code>apcupsd.conf</code> file in <code>/etc/apcupsd/</code> but i'm pretty sure that the default settings are fine for most implementations.  The one exception may be the <code>UPSNAME</code> directive which you may wish to customise, but it doesnt appear to have a bearing on anything in my environment.</li>
<li>This container has the capability to gracefully shut down the physical host if there is a prolonged power failure. This is done using a DBus system call to the underlying host, though it’s necessary to run the container in privileged mode, and explicitly expose  /var/run/dbus/system_bus_socket  from the host into the guest. You can test this by running <code>/etc/apcupsd/apccontrol doshutdown</code> within this container, which should power off the host gracefully. This has been tested with the limited hosts I have in my lab environment and works successfully on Ubuntu 16.04 and 18.04 hosts.  Your mileage may vary.  If you run into difficulties, the action that triggers the host to shut down is in the <code>/etc/apcupsd/doshutdown</code> file inside the container.  This file contains commented out lines for restarting instead of shutting down, for use when testing.  it also has lines for managing Consolekit environments, which I'm lead to believe from my research behave differently in some way, but I've no way of testing this, so I just included them for completeness. For persistence, you may want to put this file on the host and bind mount it to the container as you've probably also already done with <code>/etc/apcupsd/apcupsd.conf</code>.</li>
<li>The apcupsd software operates a Network information Server model (NIS) for sharing information between hosts.  The remote hosts (those not directly connected to the UPS) poll the apcupsd instance that <u>is</u> directly connected to the UPS regular intervals.  All of this is customisable. For more information please see the apcupsd manual online here : <a href="http://www.apcupsd.org/manual/">APC UPS Daemon User Manual</a></li>
</ul>  
