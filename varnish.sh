#!/bin/bash

   curl -s https://packagecloud.io/install/repositories/varnishcache/varnish65/script.rpm.sh | bash 
   
   dnf -y install varnish
   rpm  --quiet -q varnish

   wget -qO /etc/systemd/system/varnish.service https://raw.githubusercontent.com/magenx/Magento-2-server-installation/master/varnish.service
   wget -qO /etc/varnish/varnish.params https://raw.githubusercontent.com/magenx/Magento-2-server-installation/master/varnish.params
   uuidgen > /etc/varnish/secret
   systemctl daemon-reload
