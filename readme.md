## Debian 7 VPS Script

Remove excess packages (apache2, sendmail, bind9, samba, nscd, etc) and install the basic components needed for a light-weight HTTP(S) web server:

 - dropbear (SSH)
 - iptables (firewall)
 - syslogd
 - exim4 (light mail server)
 - nginx (v1.2+ from dotdeb, configured for lowend VPS. Change worker_processes in nginx.conf according to number of CPUs)
 - nano, mc, htop, iftop & iotop

Includes sample nginx config files for PHP sites. You can create a basic site shell (complete with nginx vhost) like this:

./setup-debian.sh site example.com

When running the iptables or dropbear install you must specify a SSH port. Remember, port 22 is the default. It's recommended that you change this from 22 just to save server load from attacks on that port.

## Usage (in recommended order)

    01. ssh root@{your_ip}
    02. passwd
    03. /usr/sbin/groupadd wheel
    04. /usr/sbin/visudo
        a. # or visudo 
        b. %wheel  ALL=(ALL)       ALL
    05. /usr/sbin/adduser {user}
        a. #or useradd {user}
    06. /usr/sbin/usermod -a -G wheel {user}
    07. scp ~/.ssh/id_rsa.pub {user}@{your_ip}:
    08. mkdir ~{user}/.ssh:
    09. mv ~{user}/id_rsa.pub ~{user}/.ssh/authorized_keys
    10. chown -R {user}:{user} ~{user}/.ssh
    11. chmod 700 ~{user}/.ssh
    12. chmod 600 ~{user}/.ssh/authorized_keys
    13. nano /etc/ssh/sshd_config
        a. Port {port}
        b. Protocol 2
        c. PermitRootLogin no
        d. PasswordAuthentication no
        e. UseDNS no
        f. AllowUsers {user}
        g. X11Forwarding no
    14. /etc/init.d/ssh reload


### Warning! This script will overwrite previous configs during reinstallation.

	wget --no-check-certificate https://raw.github.com/peterdorsi/lowendscript/master/setup-debian.sh 
	chmod +x setup-debian.sh
	./setup-debian.sh dotdeb # not required if using Ubuntu
	./setup-debian.sh system
	./setup-debian.sh iptables [port]
	./setup-debian.sh nginx
	./setup-debian.sh php
	./setup-debian.sh exim4
	./setup-debian.sh site [domain.tld]

#### ... and now time for some extras

##### Webmin

	./setup-debian.sh webmin

##### vzfree

Supported only on OpenVZ only, vzfree reports correct memory usage

	./setup-debian.sh vzfree

##### Classic Disk I/O and Network test

Run the classic Disk IO (dd) & Classic Network (cachefly) Test

	./setup-debian.sh test

##### Neat python script to report memory usage per app

Neat python script to report memory usage per app

	./setup-debian.sh ps_mem

##### sources.list updating (Ubuntu only)

Updates Ubuntu /etc/apt/sources.list to default based on whatever version you are running

	./setup-debian.sh apt

##### Info on Operating System, version and Architecture

	./setup-debian.sh info

##### SSH-Keys

Either you want to generate ssh-keys (id_rsa) or a custom key for something (rsync etc)
Note: argument is optional, if its left out, it will write "id_rsa" key

	./setup-debian.sh sshkey [optional argument_1]
    
##### Extras

Fixing locale on some OpenVZ Ubuntu templates

	./setup-debian.sh locale

Configure or reconfigure MOTD

	./setup-debian.sh motd

## After installation

- After installing the full set, RAM usage reaches ~40-45MB.
- I recommend installing Ajenti and/or Webmin to manage your VPS.

## Credits

- [LowEndBox admin (LEA)](https://github.com/lowendbox/lowendscript)
- [Xeoncross](https://github.com/Xeoncross/lowendscript),
- [ilevkov](https://github.com/ilevkov/lowendscript),
- [asimzeeshan](https://github.com/asimzeeshan)
- and many others!
