#!/bin/bash
# Wait until PostgreSQL started and listens on port 5432.
while [ -z "$(netstat -tln | grep 5432)" ]; do
  echo 'Waiting for PostgreSQL to start ...'
  sleep 1
done
echo 'PostgreSQL started.'
sleep 5
# Ensure permissions are correct at runtime (in case volumes are mounted)
mkdir -p /etc/fusionpbx
chown -R www-data:www-data /etc/fusionpbx
chown -R www-data:www-data /var/www/fusionpbx
chown -R freeswitch:freeswitch /var/log/freeswitch
chown -R freeswitch:freeswitch /var/lib/freeswitch
chown -R freeswitch:freeswitch /etc/freeswitch
# Start server.
echo 'Starting Freeswitch...'
# -nf: No Fork (Stay in foreground for Supervisor)
# -nc: No Console (Don't hog stdout needlessly, though Supervisor captures it)
# -nonat: Disable NAT detection (optional, depends on network mode)
/usr/bin/freeswitch -u freeswitch -g freeswitch -nf -nc -nonat
