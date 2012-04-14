## Debian 6 VPS Script

Remove excess packages and install the basic components needed for a light-weight HTTP(S) web server.

 - dropbear (SSH)
 - iptables (firewall)
 - dash (replaces bash)
 - syslogd
 - MySQL (+5.5 from dotdeb)
 - PHP-FPM
 - nginx (+1.0 from dotdeb)
 - vim, nano, mc, htop, iftop & iotop (more to come...)

Includes sample nginx config files for PHP sites. You can create a basic site shell (complete with nginx vhost) like this:

./setup-debian.sh site example.com

When running the iptables or dropbear install you must specify a SSH port. Remember, port 22 is the default. It's recomended that you change this from 22 just to save server load from attacks on that port.

## Usage (in recomended order):  
# Warning! This script is self destructive, it'll overwrite previous configs during reinstallation.  
 wget --no-check-certificate https://github.com/ilevkov/lowendscript/raw/master/setup-debian.sh  
 bash setup-debian.sh dotdeb  
 bash setup-debian.sh system  
 bash setup-debian.sh dropbear  
 bash setup-debian.sh iptables  
 bash setup-debian.sh mysql  
 bash setup-debian.sh nginx  
 bash setup-debian.sh php  
 bash setup-debian.sh site example.com  

