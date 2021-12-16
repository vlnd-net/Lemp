#!/bin/bash


dnf -y module install redis
  rpm  --quiet -q redis
  systemctl disable redis
     echo
      rpm -qa 'redis*' | awk '{print "  Installed: ",$1}'
     redis_conf="/etc/redis.conf"
 
echo
cat > /etc/systemd/system/redis@.service <<END
[Unit]
Description=Advanced key-value store at %i
After=network.target
[Service]
Type=forking
User=redis
Group=redis
PrivateTmp=true
RuntimeDirectory=redis-%i
RuntimeDirectoryMode=2755
UMask=007
PrivateTmp=yes
LimitNOFILE=65535
PrivateDevices=yes
ProtectHome=yes
ReadOnlyDirectories=/
ReadWritePaths=-/var/lib/redis
ReadWritePaths=-/var/log/redis
ReadWritePaths=-/run/redis-%i
PIDFile=/run/redis-%i/redis-%i.pid
ExecStart=/usr/bin/redis-server /etc/redis/redis-%i.conf
Restart=on-failure
ProtectSystem=true
ReadWriteDirectories=-/etc/redis
[Install]
WantedBy=multi-user.target
END

for REDISPORT in 6379 6380
do
mkdir -p /var/lib/redis-${REDISPORT}
chmod 755 /var/lib/redis-${REDISPORT}
chown redis /var/lib/redis-${REDISPORT}
mkdir -p /etc/redis/
cp -rf ${redis_conf} /etc/redis/redis-${REDISPORT}.conf
chown redis /etc/redis/redis-${REDISPORT}.conf
chmod 644 /etc/redis/redis-${REDISPORT}.conf
sed -i "s/^bind 127.0.0.1.*/bind 127.0.0.1/"  /etc/redis/redis-${REDISPORT}.conf
sed -i "s/^dir.*/dir \/var\/lib\/redis-${REDISPORT}\//"  /etc/redis/redis-${REDISPORT}.conf
sed -i "s/^logfile.*/logfile \/var\/log\/redis\/redis-${REDISPORT}.log/"  /etc/redis/redis-${REDISPORT}.conf
sed -i "s/^pidfile.*/pidfile \/run\/redis-${REDISPORT}\/redis-${REDISPORT}.pid/"  /etc/redis/redis-${REDISPORT}.conf
sed -i "s/^port.*/port ${REDISPORT}/" /etc/redis/redis-${REDISPORT}.conf
sed -i "s/dump.rdb/dump-${REDISPORT}.rdb/" /etc/redis/redis-${REDISPORT}.conf
sed -i "/save [0-9]0/d" /etc/redis/redis-${REDISPORT}.conf
sed -i 's/^#.*save ""/save ""/' /etc/redis/redis-${REDISPORT}.conf
sed -i '/^# rename-command CONFIG ""/a\
rename-command SLAVEOF "" \
rename-command CONFIG "" \
rename-command PUBLISH "" \
rename-command SAVE "" \
rename-command SHUTDOWN "" \
rename-command DEBUG "" \
rename-command BGSAVE "" \
rename-command BGREWRITEAOF ""
'  /etc/redis/redis-${REDISPORT}.conf
done
echo
systemctl daemon-reload
systemctl enable redis@6379
systemctl enable redis@6380
systemctl stop redis-server
systemctl disable redis-server
systemctl restart redis@6379 redis@6380
 else
  echo
  REDTXT "REDIS INSTALLATION ERROR"
 exit 1
 fi
  else
   echo
   YELLOWTXT "Redis installation was skipped by the user. Next step"
fi
echo
WHITETXT "============================================================================="
