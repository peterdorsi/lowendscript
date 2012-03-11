## Debian 6 VPS Script

Remove excess packages and install the basic components needed for a light-weight HTTP(S) web server.

 - dropbear (SSH)
 - iptables (firewall)
 - dash (replaces bash)
 - syslogd
 - MySQL
 - PHP-FPM
 - nginx (+1.0 from dotdeb)
 - vim & nano

Includes sample nginx config files for PHP sites. You can create a basic site shell (complete with nginx vhost) like this:

./setup-debian.sh site example.com

When running the iptables or dropbear install you must specify a SSH port. Remember, port 22 is the default. It's recomended that you change this from 22 just to save server load from attacks on that port.
