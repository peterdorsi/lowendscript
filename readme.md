## Debian 6 VPS Script

Remove excess packages and install the basic components needed for a light-weight HTTP(S) web server.

 - dropbear (SSH)
 - iptables (firewall)
 - dash (replaces bash)
 - syslogd
 - MySQL (v5.1+)
 - PHP-FPM (v5.3+)
 - exim4 (light mail server)
 - nginx (v1.0+ from dotdeb)
 - vim, nano, mc, htop, iftop & iotop (more to come...)

Includes sample nginx config files for PHP sites. You can create a basic site shell (complete with nginx vhost) like this:

./setup-debian.sh site example.com

When running the iptables or dropbear install you must specify a SSH port. Remember, port 22 is the default. It's recomended that you change this from 22 just to save server load from attacks on that port.

## Usage (in recomended order):  
### Warning! This script is self destructive, it'll overwrite previous configs during reinstallation.  
 wget --no-check-certificate https://github.com/ilevkov/lowendscript/raw/master/setup-debian.sh  
 bash setup-debian.sh dotdeb  
 bash setup-debian.sh system  
 bash setup-debian.sh dropbear 22  # or any other port number  
 bash setup-debian.sh iptables  
 bash setup-debian.sh mysql  
 bash setup-debian.sh nginx  
 bash setup-debian.sh php  
 bash setup-debian.sh exim4   
 bash setup-debian.sh site example.com  
  
## After installation:  
After installing the full, set ram usage reaches ~70-75Mb, this is due to caching (APC in this case) is being enabled during installation.  
To reduce ram usage by 30Mb you may disable APC by moving or deleting the following fil - /etc/php5/fpm/conf.d/apc.ini  
