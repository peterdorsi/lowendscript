#!/bin/bash

function check_install {
	if [ -z "`which "$1" 2>/dev/null`" ]
	then
		executable=$1
		shift
		while [ -n "$1" ]
		do
			DEBIAN_FRONTEND=noninteractive apt-get -q -y install "$1"
			print_info "$1 installed for $executable"
			shift
		done
	else
		print_warn "$2 already installed"
	fi
}

function check_remove {
	if [ -n "`which "$1" 2>/dev/null`" ]
	then
		DEBIAN_FRONTEND=noninteractive apt-get -q -y remove --purge "$2"
		print_info "$2 removed"
	else
		print_warn "$2 is not installed"
	fi
}

function check_sanity {
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die 'Must be run by root user'
	fi

	if [ ! -f /etc/debian_version ]
	then
		die "Distribution is not supported"
	fi
}

function die {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}

function get_domain_name() {
	# Getting rid of the lowest part.
	domain=${1%.*}
	lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
	case "$lowest" in
	com|net|org|gov|edu|co|me|info|name)
		domain=${domain%.*}
		;;
	esac
	lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
	[ -z "$lowest" ] && echo "$domain" || echo "$lowest"
}

function get_password() {
	# Check whether our local salt is present.
	SALT=/var/lib/radom_salt
	if [ ! -f "$SALT" ]
	then
		head -c 512 /dev/urandom > "$SALT"
		chmod 400 "$SALT"
	fi
	password=`(cat "$SALT"; echo $1) | md5sum | base64`
	echo ${password:0:13}
}

function print_info {
	echo -n -e '\e[1;36m'
	echo -n $1
	echo -e '\e[0m'
}

function print_warn {
	echo -n -e '\e[1;33m'
	echo -n $1
	echo -e '\e[0m'
}


## Installation of Applications


function install_dash {
	check_install dash dash
	rm -f /bin/sh
	ln -s dash /bin/sh
}

function install_nano {
	check_install nano nano
}

function install_htop {
	check_install htop htop
}

function install_mc {
	check_install mc mc
}

function install_iotop {
	check_install iotop iotop
}

function install_iftop {
	check_install iftop iftop
	print_warn "Run IFCONFIG to find your net. device name"
	print_warn "Example usage: iftop -i venet0"
}

function install_vim {
	check_install vim vim
}

function install_dropbear {

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` dropbear [ssh-port-#]"
	fi

	check_install dropbear dropbear
	check_install /usr/sbin/xinetd xinetd

	# Disable SSH
	touch /etc/ssh/sshd_not_to_be_run
	invoke-rc.d ssh stop

	# Enable dropbear to start. We are going to use xinetd as it is just
	# easier to configure and might be used for other things.
	cat > /etc/xinetd.d/dropbear <<END
service ssh
{
	socket_type  = stream
	only_from    = 0.0.0.0
	wait         = no
	user         = root
	protocol     = tcp
	server       = /usr/sbin/dropbear
	server_args  = -i
	disable      = no
	port         = $1
	type         = unlisted
}
END
	invoke-rc.d xinetd restart
}

function install_exim4 {
	check_install mail exim4
	if [ -f /etc/exim4/update-exim4.conf.conf ]
	then
		sed -i \
			"s/dc_eximconfig_configtype='local'/dc_eximconfig_configtype='internet'/" \
			/etc/exim4/update-exim4.conf.conf
		invoke-rc.d exim4 restart
	fi
}

function install_dotdeb {
	#echo "deb http://mirror.us.leaseweb.net/dotdeb/ stable all" >> /etc/apt/sources.list
	#echo "deb-src http://mirror.us.leaseweb.net/dotdeb/ stable all" >> /etc/apt/sources.list
	echo "deb http://packages.dotdeb.org squeeze all" >> /etc/apt/sources.list
	echo "deb-src http://packages.dotdeb.org squeeze all" >> /etc/apt/sources.list
	wget -q -O - http://www.dotdeb.org/dotdeb.gpg | apt-key add -
}

function install_syslogd {
	# We just need a simple vanilla syslogd. Also there is no need to log to
	# so many files (waste of fd). Just dump them into
	# /var/log/(cron/mail/messages)
	check_install /usr/sbin/syslogd inetutils-syslogd
	invoke-rc.d inetutils-syslogd stop

	for file in /var/log/*.log /var/log/mail.* /var/log/debug /var/log/syslog
	do
		[ -f "$file" ] && rm -f "$file"
	done
	for dir in fsck news
	do
		[ -d "/var/log/$dir" ] && rm -rf "/var/log/$dir"
	done

	cat > /etc/syslog.conf <<END
*.*;mail.none;cron.none -/var/log/messages
cron.*				  -/var/log/cron
mail.*				  -/var/log/mail
END

	[ -d /etc/logrotate.d ] || mkdir -p /etc/logrotate.d
	cat > /etc/logrotate.d/inetutils-syslogd <<END
/var/log/cron
/var/log/mail
/var/log/messages {
	rotate 4
	weekly
	missingok
	notifempty
	compress
	sharedscripts
	postrotate
		/etc/init.d/inetutils-syslogd reload >/dev/null
	endscript
}
END

	invoke-rc.d inetutils-syslogd start
}

function install_mysql {

	# Install the MySQL packages
	check_install mysqld mysql-server
	check_install mysql mysql-client

	# Install a low-end copy of the my.cnf to disable InnoDB
	invoke-rc.d mysql stop
	cat > /etc/mysql/conf.d/lowendbox.cnf <<END
[mysqld]
key_buffer = 12M
query_cache_size = 0
table_cache = 32

ignore_builtin_innodb
default_storage_engine=MyISAM
END
	invoke-rc.d mysql start

	# Generating a new password for the root user.
	passwd=`get_password root@mysql`
	mysqladmin password "$passwd"
	cat > ~/.my.cnf <<END
[client]
user = root
password = $passwd
END
	chmod 600 ~/.my.cnf
}

function install_php {
	# PHP core
	check_install php5-fpm php5-fpm
	check_install php5-cli php5-cli

	# PHP modules
	DEBIAN_FRONTEND=noninteractive apt-get -y install php-apc php5-suhosin php5-curl php5-gd php5-intl php5-mcrypt php-gettext php5-mysql php5-sqlite

	echo 'Using PHP-FPM to manage PHP processes'
	echo ' '

	mv /etc/php5/conf.d/apc.ini /etc/php5/conf.d/orig.apc.ini

cat > /etc/php5/conf.d/apc.ini <<END
[APC]
extension=apc.so
apc.enabled=1
apc.shm_segments=1
apc.shm_size=16
apc.ttl=7200
apc.user_ttl=7200
apc.num_files_hint=1024
apc.mmap_file_mask=/tmp/apc.XXXXXX
apc.max_file_size = 1M
apc.post_max_size = 1000M
apc.upload_max_filesize = 1000M
apc.enable_cli=0
apc.rfc1867=0
END

	mv /etc/php5/conf.d/suhosin.ini /etc/php5/conf.d/orig.suhosin.ini

cat > /etc/php5/conf.d/suhosin.ini <<END
; configuration for php suhosin module
extension=suhosin.so
suhosin.executor.include.whitelist="phar"
suhosin.request.max_vars = 2048
suhosin.post.max_vars = 2048
suhosin.request.max_array_index_length = 256
suhosin.post.max_array_index_length = 256
suhosin.request.max_totalname_length = 8192
suhosin.post.max_totalname_length = 8192
suhosin.sql.bailout_on_error = Off
END

	if [ -f /etc/php5/fpm/php.ini ]
		then
			sed -i \
				"s/upload_max_filesize = 2M/upload_max_filesize = 200M/" \
				/etc/php5/fpm/php.ini
			sed -i \
				"s/post_max_size = 8M/post_max_size = 200M/" \
				/etc/php5/fpm/php.ini
			sed -i \
				"s/memory_limit = 128M/memory_limit = 36M/" \
				/etc/php5/fpm/php.ini
	fi

	invoke-rc.d php5-fpm restart

}

function install_nginx {

	check_install nginx nginx

	mkdir -p /var/www

	# PHP-safe default vhost
	cat > /etc/nginx/sites-available/default_php <<END
# Creates unlimited domains for PHP sites as long as you add the
# entry to /etc/hosts and create the matching \$host folder.
server {
	listen 80 default;
	server_name _;
	root /var/www/\$host/public;
	index index.html index.htm index.php;

	# Directives to send expires headers and turn off 404 error logging.
	location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
		expires max;
		log_not_found off;
		access_log off;
	}

	location = /favicon.ico {
		log_not_found off;
		access_log off;
	}

	location = /robots.txt {
		allow all;
		log_not_found off;
		access_log off;
	}

	## Disable viewing .htaccess & .htpassword
	location ~ /\.ht {
		deny  all;
	}

	include /etc/nginx/php.conf;
}
END

	# MVC frameworks with only a single index.php entry point (nginx > 0.7.27)
	cat > /etc/nginx/php.conf <<END
# Route all requests for non-existent files to index.php
location / {
	try_files \$uri \$uri/ /index.php\$is_args\$args;
}

# Pass PHP scripts to php-fastcgi listening on port 9000
location ~ \.php$ {

	# Zero-day exploit defense.
	# http://forum.nginx.org/read.php?2,88845,page=3
	# Won't work properly (404 error) if the file is not stored on
	# this server,  which is entirely possible with php-fpm/php-fcgi.
	# Comment the 'try_files' line out if you set up php-fpm/php-fcgi
	# on another machine.  And then cross your fingers that you won't get hacked.
	try_files \$uri =404;

	include fastcgi_params;

	# Keep these parameters for compatibility with old PHP scripts using them.
	fastcgi_param PATH_INFO \$fastcgi_path_info;
	fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_path_info;
	fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;

	# Some default config
	fastcgi_connect_timeout        20;
	fastcgi_send_timeout          180;
	fastcgi_read_timeout          180;
	fastcgi_buffer_size          128k;
	fastcgi_buffers            4 256k;
	fastcgi_busy_buffers_size    256k;
	fastcgi_temp_file_write_size 256k;
	fastcgi_intercept_errors    on;
	fastcgi_ignore_client_abort off;
	fastcgi_pass 127.0.0.1:9000;

}
# PHP search for file Exploit:
# The PHP regex location block fires instead of the try_files block. Therefore we need
# to add "try_files \$uri =404;" to make sure that "/uploads/virusimage.jpg/hello.php"
# never executes the hidden php code inside virusimage.jpg because it can't find hello.php!
# The exploit also can be stopped by adding "cgi.fix_pathinfo = 0" in your php.ini file.
END

	echo 'Created /etc/nginx/php.conf for PHP sites'
	echo 'Created /etc/nginx/sites-available/default_php sample vhost'
	echo ' '
 if [ -f /etc/nginx/nginx.conf ]
	then
		sed -i \
			"s/worker_processes 4;/worker_processes 1;/" \
			/etc/nginx/nginx.conf
		sed -i \
			"s/worker_connections 768;/worker_connections 1024;/" \
			/etc/nginx/nginx.conf
 fi
	invoke-rc.d nginx restart
}

function install_site {

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` site [domain]"
	fi

	# Setup folder
	mkdir /var/www/$1
	mkdir /var/www/$1/public

	# Setup default index.html file
	cat > "/var/www/$1/public/index.html" <<END
Hello World
END

	# Setup test phpinfo.php file
	echo "<?php phpinfo(); ?>" > /var/www/$1/public/phpinfo.php
	chown www-data:www-data "/var/www/$1/public/phpinfo.php"

	# Setting up Nginx mapping
	cat > "/etc/nginx/sites-available/$1.conf" <<END
server {
	listen 80;
	server_name www.$1 $1;
	root /var/www/$1/public;
	index index.html index.htm index.php;

	access_log  /var/www/$1/access.log;
	error_log  /var/www/$1/error.log;

	# Directives to send expires headers and turn off 404 error logging.
	location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
		expires max;
		log_not_found off;
		access_log off;
	}

	location = /favicon.ico {
		log_not_found off;
		access_log off;
	}

	location = /robots.txt {
		allow all;
		log_not_found off;
		access_log off;
	}

	## Disable viewing .htaccess & .htpassword
	location ~ /\.ht {
		deny  all;
	}

	include /etc/nginx/php.conf;
}
END
	# Create the link so nginx can find it
	ln -s /etc/nginx/sites-available/$1.conf /etc/nginx/sites-enabled/$1.conf

	# PHP/Nginx needs permission to access this
	chown www-data:www-data -R "/var/www/$1"

	invoke-rc.d nginx restart

	print_warn "New site successfully installed."
	print_warn "You may can test PHP functionality by accessing $1/phpinfo.php"
}

function install_mysqluser {

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` mysqluser [domain]"
	fi

	if [ ! -d "/var/www/$1/" ]
	then
		echo "no site found at /var/www/$1/"
		exit
	fi

	# Setting up the MySQL database
	dbname=`echo $1 | tr . _`
	userid=`get_domain_name $1`
	# MySQL userid cannot be more than 15 characters long
	userid="${userid:0:15}"
	passwd=`get_password "$userid@mysql"`

	cat > "/var/www/$1/mysql.conf" <<END
[mysql]
user = $userid
password = $passwd
database = $dbname
END
	chmod 600 "/var/www/$1/mysql.conf"

	mysqladmin create "$dbname"
	echo "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO \`$userid\`@localhost IDENTIFIED BY '$passwd';" | \
		mysql

	# We could also add these...
	#echo "DROP USER '$userid'@'localhost';" | \ mysql
	#echo "DROP DATABASE IF EXISTS  `$dbname` ;" | \ mysql

	echo 'MySQL Username: ' $userid
	echo 'MySQL Password: ' $passwd
	echo 'MySQL Database: ' $dbname
}


function install_iptables {

	check_install iptables

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` iptables [ssh-port-#]"
	fi

	# Create startup rules
	cat > /etc/iptables.up.rules <<END
*filter

# http://articles.slicehost.com/2010/4/30/ubuntu-lucid-setup-part-1

#  Allows all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0
-A INPUT -i lo -j ACCEPT
-A INPUT ! -i lo -d 127.0.0.0/8 -j REJECT

#  Accepts all established inbound connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#  Allows all outbound traffic
#  You can modify this to only allow certain traffic
-A OUTPUT -j ACCEPT

# Allows HTTP and HTTPS connections from anywhere (the normal ports for websites)
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 443 -j ACCEPT

# UN-COMMENT THESE IF YOU USE INCOMING MAIL!

# Allows POP (and SSL-POP)
#-A INPUT -p tcp --dport 110 -j ACCEPT
#-A INPUT -p tcp --dport 995 -j ACCEPT

# SMTP (and SSMTP)
#-A INPUT -p tcp --dport 25 -j ACCEPT
#-A INPUT -p tcp --dport 465 -j ACCEPT

# IMAP (and IMAPS)
#-A INPUT -p tcp --dport 143 -j ACCEPT
#-A INPUT -p tcp --dport 993 -j ACCEPT

#  Allows SSH connections (only 3 attempts by an IP every minute, drop the rest to prevent SSH attacks)
-A INPUT -p tcp -m tcp --dport $1 -m state --state NEW -m recent --set --name DEFAULT --rsource
-A INPUT -p tcp -m tcp --dport $1 -m state --state NEW -m recent --update --seconds 60 --hitcount 3 --name DEFAULT --rsource -j DROP
-A INPUT -p tcp -m state --state NEW --dport $1 -j ACCEPT

# Allow ping
-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT

# log iptables denied calls (Can grow log files fast!)
#-A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables denied: " --log-level 7

# Reject all other inbound - default deny unless explicitly allowed policy
#-A INPUT -j REJECT
#-A FORWARD -j REJECT

# It's safer to just DROP the packet
-A INPUT -j DROP
-A FORWARD -j DROP

COMMIT
END

	# Set these rules to load on startup
	cat > /etc/network/if-pre-up.d/iptables <<END
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.up.rules
END

	# Make it executable
	chmod +x /etc/network/if-pre-up.d/iptables

	# Load the rules
	iptables-restore < /etc/iptables.up.rules

	# You can flush the current rules with /sbin/iptables -F
	echo 'Created /etc/iptables.up.rules and startup script /etc/network/if-pre-up.d/iptables'
	echo 'If you make changes you can restore the rules with';
	echo '/sbin/iptables -F'
	echo 'iptables-restore < /etc/iptables.up.rules'
	echo ' '
}

function remove_unneeded {
	# Some Debian have portmap installed. We don't need that.
	check_remove /sbin/portmap portmap

	# Remove rsyslogd, which allocates ~30MB privvmpages on an OpenVZ system,
	# which might make some low-end VPS inoperatable. We will do this even
	# before running apt-get update.
	check_remove /usr/sbin/rsyslogd rsyslog

	# Other packages that seem to be pretty common in standard OpenVZ
	# templates.
	check_remove /usr/sbin/apache2 'apache2*'
	check_remove /usr/sbin/named bind9
	check_remove /usr/sbin/smbd 'samba*'
	check_remove /usr/sbin/nscd nscd

	# Need to stop sendmail as removing the package does not seem to stop it.
	if [ -f /usr/lib/sm.bin/smtpd ]
	then
		invoke-rc.d sendmail stop
		check_remove /usr/lib/sm.bin/smtpd 'sendmail*'
	fi
}

function update_upgrade {
	# Run through the apt-get update/upgrade first. This should be done before
	# we try to install any package
	apt-get -q -y update
	apt-get -q -y upgrade
}

function update_timezone {
	dpkg-reconfigure tzdata
}


########################################################################
# START OF PROGRAM
########################################################################
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

check_sanity
case "$1" in
mysql)
	install_mysql
	;;
exim4)
	install_exim4
	;;
nginx)
	install_nginx
	;;
php)
	install_php
	;;
dotdeb)
	install_dotdeb
	;;
site)
	install_site $2
	;;
mysqluser)
	install_mysqluser $2
	;;
iptables)
	install_iptables $2
	;;
dropbear)
	install_dropbear $2
	;;
system)
	update_timezone
	remove_unneeded
	update_upgrade
	install_dash
	install_vim
	install_nano
	install_htop
	install_mc
	install_iotop
	install_iftop
	install_syslogd
	;;
*)
	echo 'Usage:' `basename $0` '[option] [argument]'
	echo 'Available options (in recomended order):'
	echo '  - dotdeb                 (install dotdeb apt source for nginx +1.0)'
	echo '  - system                 (remove unneeded, upgrade system, install software)'
	echo '  - exim4                  (install exim4 mail server)'
	echo '  - dropbear  [port]       (SSH server)'
	echo '  - iptables  [port]       (setup basic firewall with HTTP(S) open)'
	echo '  - mysql                  (install MySQL and set root password)'
	echo '  - nginx                  (install nginx and create sample PHP vhosts)'
	echo '  - php                    (install PHP5-FPM with APC, cURL, suhosin, etc...)'
	echo '  - site      [domain.tld] (create nginx vhost and /var/www/$site/public)'
	echo '  - mysqluser [domain.tld] (create matching mysql user and database)'
	echo '  '
	;;
esac
