# apcupsd-master-slave
This is an Ubuntu-based Docker container with <code>apcupsd</code> installed. It manages/monitors one or more connected UPS devices and has the ability to gracefully shut down the host computer, and the UPS itself, in the event of a prolonged power outage.  This is done with no customization to the host whatsoever, there's no need for cron jobs on the host, or trigger files and scripts.  Everything is done within the container.  Postfix is also present to support Email and SMS notifications of power events, via Gmail's SMTP service.

This project can be used standalone, although there are also sister containers available for apcupsd-cgi and a near-zero configuration TIG (telegraf-InfluxDB-Grafana) stack available to monitor your UPS units.  A full write-up can be found here https://technologydragonslayer.com/2023/01/31/ultimate-apc-ups-monitoring-with-apcupsd-admin-plus-and-docker/:

apcupsd-cgi:
![screenshot-raspberrypi10-2023 04 29-14_49_05](https://user-images.githubusercontent.com/41088895/235323855-837810a1-b6f2-40c2-a39a-eae360902178.png)

TIG stack:
![screencapture-apcupsd-2023-04-29-14_56_00](https://user-images.githubusercontent.com/41088895/235324008-e1a9cb27-252a-402f-98c2-83243f5b6b4a.png)

### Use Cases:
Use this image if your UPS is connected to your docker host by USB Cable and you don't want to run <code>apcupsd</code> in the physical host OS.

Equally, this container can be run on any other host (SLAVE) to monitor another instance of this container running on a host (MASTER) connected to the UPS for power status messages from the UPS, and take action to gracefully shut down the non-UPS connected host. Shutdowns of systems running Linux, Windows and Proxmox are all possible.

The purpose of this image is to containerise the APC UPS monitoring daemon so that it is separated from the OS, yet still has access to the UPS via USB Cable.  

### Configuration:

Very little configuration is currently required for this image to work, though you may be required to tweak the USB device that is passed through to your container by docker.

Portainer is the recommended tool here, and makes maintaining and updating this conatiner substantially easier -- particularly if you have multiple APC UPS units, and multiple other systems you wish to be shutdown when power is lost.

Below is the "full" annotated docker-compose for Portainer-Stacks, for use with either an apcupsd MASTER (i.e. connected to the UPS) or SLAVE (i.e. using input from another apcupsd daemon to determine shutdown). The healthcheck section is optional, but polls the status the UPS connection in the case of a standalone or MASTER connected system, or the status of the connection to the MASTER in the case of a SLAVE system.:

#### Fully annotated docker-compose for STANDALONE, MASTER or SLAVE use (Portainer-Stacks recommended):

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
#      - ONBATTERYDELAY=${ONBATTERYDELAY} # Sets the time in seconds from when a power failure is detected until an onbattery event is initiated (default=6)
#      - BATTERYLEVEL=${BATTERYLEVEL} # Sets the daemon to send the poweroff signal when the UPS reports a battery level of x% or less (default=5)
#      - MINUTES=${MINUTES} # Sets the daemon to send the poweroff signal when the UPS has x minutes or less remaining power (default=5)
#      - TIMEOUT=${TIMEOUT} # Sets the daemon to send the poweroff signal when the UPS has been ON battery power for x seconds (default=0)
#      - KILLDELAY=${KILLDELAY} # If non-zero, sets the daemon to attempt to turn the UPS off x seconds after sending a shutdown request (default=0)
#      - SELFTEST=${SELFTEST} # Sets the daemon to ask the UPS to perform a self test every x hours (default=336)
#      - APCUPSD_HOSTS=${APCUPSD_HOSTS} # If this is the MASTER, then enter the APUPSD_HOSTS list here, including this system (space separated)
#      - APCUPSD_NAMES=${APCUPSD_NAMES} # Match the order of this list one-to-one to APCUPSD_HOSTS list, including this system (space separated)
      - SHUTDOWN_SCRIPT=${SHUTDOWN_SCRIPT} # Changes the default /sbin/shutdown to something that will actually shutdown the host (/etc/apcupsd/doshutdown recommended
      - TZ=${TZ}
      - SMTP_GMAIL=${SMTP_GMAIL} # Gmail account (with 2FA enabled) to use for SMTP
      - GMAIL_APP_PASSWD=${GMAIL_APP_PASSWD} # App password for apcupsd from Gmail account being used for SMTP
      - NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL} # The Email account to receive on/off battery messages and other notifications (Any valid Email will work)
      - WOLWEB_HOSTNAMES=${WOLWEB_HOSTNAMES} # Space seperated list of hostnames names to send WoL Magic Packet to on startup
      - WOLWEB_PATH_BASE=${WOLWEB_PATH_BASE} # Everything after http:// and before the /hostname required to wake a system with WoLweb e.g. raspberrypi6:8089/wolweb/wake
      - WOLWEB_DELAY=${WOLWEB_DELAY} # Value to use for "sleep" delay before sending a WoL Magic Packet to WOLWEB_HOSTNAMES in seconds
    healthcheck:
      test: ["CMD-SHELL", "apcaccess | grep -E 'ONLINE' >> /dev/null"] # Command to check health
      interval: 30s # Interval between health checks
      timeout: 5s # Timeout for each health check
      retries: 3 # How many times to retry
      start_period: 15s # Estimated time to boot
    volumes:
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket # Required to support host shutdown from the container
      - /data/apcupsd:/etc/apcupsd # /etc/apcupsd can be bound to a directory or a docker volume
    restart: unless-stopped
# volumes: # Use this section for volume bindings only
#   config: # The name of the stack will be appended to the beginning of this volume name, if the volume doesn't already exist
#     external: true # Use this directive if you created the docker volume in advance
```
Environment variables can be hardcoded into the above docker-compose, or added in the environment section of Portainer. Switch to "Advanced Mode" in Portainer-Stacks in the "Environment variables" section, and paste in the below, to get all of the possible variables in place. Put in your values in place of ${whatever}, and delete any you don't choose to use:

```console
UPSNAME=${UPSNAME}
UPSCABLE=${UPSCABLE}
UPSTYPE=${UPSTYPE}
DEVICE=${DEVICE}
POLLTIME=${POLLTIME} 
ONBATTERYDELAY=${ONBATTERYDELAY}
BATTERYLEVEL=${BATTERYLEVEL}
MINUTES=${MINUTES}
TIMEOUT=${TIMEOUT}
KILLDELAY=${KILLDELAY}
SELFTEST=${SELFTEST} 
APCUPSD_HOSTS=${APCUPSD_HOSTS}
APCUPSD_NAMES=${APCUPSD_NAMES}
SHUTDOWN_SCRIPT=${SHUTDOWN_SCRIPT}
TZ=${TZ}
SMTP_GMAIL=${SMTP_GMAIL}
GMAIL_APP_PASSWD=${GMAIL_APP_PASSWD}
NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL}
WOLWEB_HOSTNAMES=${WOLWEB_HOSTNAMES}
WOLWEB_PATH_BASE=${WOLWEB_PATH_BASE}
WOLWEB_DELAY=${WOLWEB_DELAY}
```

#### Suggested docker-compose for STANDALONE use:

```yml
version: '3.7'
services:
  apcupsd:
    image: bnhf/apcupsd:latest
    container_name: apcupsd
    devices:
      - /dev/usb/hiddev0 # This device needs to match what the APC UPS on your STANDALONE system uses
    ports:
      - 3551:3551
    environment:
      - UPSNAME=${UPSNAME} # Sets a name for the UPS (1 to 8 chars), that will be used by System Tray notifications, apcupsd-cgi and Grafana dashboards
      - TZ=${TZ}
      - SMTP_GMAIL=${SMTP_GMAIL} # Gmail account (with 2FA enabled) to use for SMTP
      - GMAIL_APP_PASSWD=${GMAIL_APP_PASSWD} # App password for apcupsd from Gmail account being used for SMTP
      - NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL} # The Email account to receive on/off battery messages and other notifications (Any valid Email will work)
    healthcheck:
      test: ["CMD-SHELL", "apcaccess | grep -E 'ONLINE' >> /dev/null"] # Command to check health of UPS connection
      interval: 30s # Interval between health checks
      timeout: 5s # Timeout for each health check
      retries: 3 # How many times to retry
      start_period: 15s # Estimated time to boot
    volumes:
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket # Required to support host shutdown from the container
      - /data/apcupsd:/etc/apcupsd # /etc/apcupsd can be bound to a directory or a docker volume
    restart: unless-stopped
```

#### Suggested docker-compose for MASTER use:

```yml
version: '3.7'
services:
  apcupsd:
    image: bnhf/apcupsd:latest
    container_name: apcupsd
    devices:
      - /dev/usb/hiddev0 # This device needs to match what the APC UPS on your APCUPSD_MASTER system uses
    ports:
      - 3551:3551
    environment:
      - UPSNAME=${UPSNAME} # Sets a name for the UPS (1 to 8 chars), that will be used by System Tray notifications, apcupsd-cgi and Grafana dashboards
      - POLLTIME=${POLLTIME} # Interval (in seconds) at which apcupsd polls the UPS for status (default=60)
      - ONBATTERYDELAY=${ONBATTERYDELAY} # Sets the time in seconds from when a power failure is detected until an onbattery event is initiated (default=6)
      - BATTERYLEVEL=${BATTERYLEVEL} # Sets the daemon to send the poweroff signal when the UPS reports a battery level of x% or less (default=5)
      - MINUTES=${MINUTES} # Sets the daemon to send the poweroff signal when the UPS has x minutes or less remaining power (default=5)
      - TIMEOUT=${TIMEOUT} # Sets the daemon to send the poweroff signal when the UPS has been ON battery power for x seconds (default=0)
      - APCUPSD_HOSTS=${APCUPSD_HOSTS} # If this is the MASTER, then enter the APUPSD_HOSTS list here, including this system (space separated)
      - APCUPSD_NAMES=${APCUPSD_NAMES} # Match the order of this list one-to-one to APCUPSD_HOSTS list, including this system (space separated)
      - TZ=${TZ}
      - SMTP_GMAIL=${SMTP_GMAIL} # Gmail account (with 2FA enabled) to use for SMTP
      - GMAIL_APP_PASSWD=${GMAIL_APP_PASSWD} # App password for apcupsd from Gmail account being used for SMTP
      - NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL} # The Email account to receive on/off battery messages and other notifications (Any valid Email will work)
    healthcheck:
      test: ["CMD-SHELL", "apcaccess | grep -E 'ONLINE' >> /dev/null"] # Command to check health
      interval: 30s # Interval between health checks
      timeout: 5s # Timeout for each health check
      retries: 3 # How many times to retry
      start_period: 15s # Estimated time to boot
    volumes:
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket # Required to support host shutdown from the container
      - /data/apcupsd:/etc/apcupsd # /etc/apcupsd can be bound to a directory or a docker volume
    restart: unless-stopped
```

#### Suggested docker-compose for SLAVE use:

```yml
version: '3.7'
services:
  apcupsd:
    image: bnhf/apcupsd:latest
    container_name: apcupsd
    ports:
      - 3551:3551
    environment:
      - UPSNAME=${UPSNAME} # Sets a name for the UPS (1 to 8 chars), that will be used by System Tray notifications, apcupsd-cgi and Grafana dashboards
      - UPSCABLE=${UPSCABLE} # Usually doesn't need to be changed on system connected to UPS. (default=usb) On APCUPSD_SLAVES set the value to ether
      - UPSTYPE=${UPSTYPE} # Usually doesn't need to be changed on system connected to UPS. (default=usb) On APCUPSD_SLAVES set the value to net
      - DEVICE=${DEVICE} # Use this only on APCUPSD_SLAVES to set the hostname or IP address of the APCUPSD_MASTER with the listening port (:3551)
      - POLLTIME=${POLLTIME} # Interval (in seconds) at which apcupsd polls the UPS for status (default=60)
      - ONBATTERYDELAY=${ONBATTERYDELAY} # Sets the time in seconds from when a power failure is detected until an onbattery event is initiated (default=6)
      - BATTERYLEVEL=${BATTERYLEVEL} # Sets the daemon to send the poweroff signal when the UPS reports a battery level of x% or less (default=5)
      - MINUTES=${MINUTES} # Sets the daemon to send the poweroff signal when the UPS has x minutes or less remaining power (default=5)
      - TIMEOUT=${TIMEOUT} # Sets the daemon to send the poweroff signal when the UPS has been ON battery power for x seconds (default=0)
#      - SELFTEST=${SELFTEST} # Sets the daemon to ask the UPS to perform a self test every x hours (default=336)
      - TZ=${TZ}
    healthcheck:
      test: ["CMD-SHELL", "apcaccess | grep -E 'ONLINE' >> /dev/null"] # Command to check health
      interval: 30s # Interval between health checks
      timeout: 5s # Timeout for each health check
      retries: 3 # How many times to retry
      start_period: 15s # Estimated time to boot
    volumes:
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket # Required to support host shutdown from the container
      - /data/apcupsd:/etc/apcupsd # /etc/apcupsd can be bound to a directory or a docker volume
    restart: unless-stopped
```
