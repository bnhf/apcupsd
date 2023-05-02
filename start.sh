#! /bin/bash

# Config file moves transferred from Dockerfile to support
# binding /etc/apcupsd to user-specified host directory

cp /opt/apcupsd/apcupsd /etc/default/apcupsd

# Check if /etc/apcupsd files exist, and copy them from /opt/apcupsd if they don't
files=( apcupsd.conf hosts.conf doshutdown apccontrol changeme commfailure commok killpower multimon.conf offbattery onbattery ups-monitor )

for i in "${files[@]}"
  do
    if [ ! -f /etc/apcupsd/$i ]; then
      cp /opt/apcupsd/$i /etc/apcupsd/$i \
      && echo "No existing $i found"
    else
      echo "Existing $i found, and will be used"
    fi
  done

# First, if not previously done, add an extra # to the second UPSNAME used for EPROM updates
sed -i 's/^#UPSNAME UPS_IDEN/##UPSNAME UPS_IDEN/' /etc/apcupsd/apcupsd.conf

# Second, if not previously done, change EVENTSFILE location to /etc/apcupsd for ease of viewing
sed -i 's|^EVENTSFILE /var/log/apcupsd.events|EVENTSFILE /etc/apcupsd/apcupsd.events|' /etc/apcupsd/apcupsd.conf

# Check if environment variables are set, and if so update apcupsd.conf
settings=( "UPSNAME" "UPSCABLE" "UPSTYPE" "DEVICE" "POLLTIME" "ONBATTERYDELAY" "BATTERYLEVEL" "MINUTES" "TIMEOUT" "KILLDELAY" "NETSERVER" "NISIP" "NISPORT" "SELFTEST" )

for i in ${settings[@]}
  do
    if [ ! -z ${!i} ]; then
      sed -i -r 's/(^'"$i"'.*|^#'"$i"'.*)/'"$i"' '"${!i}"'/' /etc/apcupsd/apcupsd.conf \
      && awk '$1 ~ /^'"$i"'/' /etc/apcupsd/apcupsd.conf
    fi
  done

# if $APCUPSD_HOSTS exists thendelete existing hosts.conf, and recreate with specified values
if [ ! -z "$APCUPSD_HOSTS" ]; then
  rm /etc/apcupsd/hosts.conf \
  && touch /etc/apcupsd/hosts.conf
fi

# populate two arrays with host and UPS names
HOSTS=( $APCUPSD_HOSTS )
NAMES=( $APCUPSD_NAMES )

# add monitors to hosts.conf for each host and UPS name combo
for ((i=0;i<${#HOSTS[@]};i++))
  do
    if [ ! -z $i ]; then
      echo "MONITOR ${HOSTS[$i]} \"${NAMES[$i]}\"" >> /etc/apcupsd/hosts.conf \
      && echo "MONITOR ${HOSTS[$i]} \"${NAMES[$i]}\""
    fi
  done

# create sasl_passwd and hash it
if [ ! -z $SMTP_GMAIL ]; then
  echo "smtp.gmail.com $SMTP_GMAIL:$GMAIL_APP_PASSWD" > /etc/postfix/sasl_passwd
  postmap hash:/etc/postfix/sasl_passwd
fi

# change notifications to external email address

notifications=( changeme offbattery onbattery )

for i in "${notifications[@]}"
  do
    if [ ! -z $NOTIFICATION_EMAIL ]; then
      sed -i 's|$SYSADMIN|'"$NOTIFICATION_EMAIL"'|' /etc/apcupsd/$i
    fi
  done

# systems to wake using WoLweb on startup (with delay in seconds)

wolweb_wakeup=( $WOLWEB_HOSTNAMES )

for i in "${wolweb_wakeup[@]}"
  do
    if [ ! -z $WOLWEB_HOSTNAMES ]; then
      ( sleep $WOLWEB_DELAY ; curl -s http://$WOLWEB_PATH_BASE/$i ) &
    fi
  done

# systems to wake using UpSnap on startup (with delay in seconds)

upsnap_wakeup=( $UPSNAP_IDS )

for i in "${upsnap_wakeup[@]}"
  do
    if [ ! -z $UPSNAP_IDS ]; then
      curl -H 'Accept: application/json' -H "Authorization: Bearer \
      $(curl -s -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' \
      --data '{"identity":'"$UPSNAP_USERNAME"',"password":'"$UPSNAP_PASSWD"',"rememberMe":false}' \
      http://$UPSNAP_PATH_BASE/api/admins/auth-with-password | jq -r '.token')" http://$UPSNAP_PATH_BASE/api/upsnap/wake/:$i
    fi
  done

# start Postfix mail service
echo "Starting Postfix SMTP Mail Server"
service postfix start

/sbin/apcupsd -b
