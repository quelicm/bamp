#!/bin/sh
#================================================================================
# bamp.sh 0.01
#
# BAMP - Installer of a Web Server with apache, mysql and php
#
# For usage help and available commands run `virtualhost.sh`.
#================================================================================
# Don't change this!

# Variables
#================================================================================
PATH_CONFIG="/Sites/"
EXT_SERVER_DEV='dev'
#================================================================================




function info {
  echo '+info: https://echo.co/blog/os-x-1010-yosemite-local-development-environment-apache-php-and-mysql-homebrew';
}

function install {
echo '\n Actualizando repositorios de Brew ####';

brew tap homebrew/apache
brew tap homebrew/completions
brew tap homebrew/dupes
brew tap homebrew/php
brew tap homebrew/versions

echo '\n ### instalando mysql ####';
brew install -v mysql

echo '\n ### Copy the default my-default.cnf file to the MySQL Homebrew Cellar directory where it will be loaded on application start';
cp -v $(brew --prefix mysql)/support-files/my-default.cnf $(brew --prefix)/etc/my.cnf

echo '\n ### well keep each InnoDB table in separate files to keep ibdataN-type file sizes low and make file-based backups, like Time Machine';
cat >> $(brew --prefix)/etc/my.cnf <<'EOF'

# Echo & Co. changes
max_allowed_packet = 1073741824
innodb_file_per_table = 1
EOF

echo '\n Uncomment the sample option for innodb_buffer_pool_size to improve performance:';
sed -i '' 's/^#[[:space:]]*\(innodb_buffer_pool_size\)/\1/' $(brew --prefix)/etc/my.cnf

echo '\n Now we need to start MySQL using OS Xs launchd. ';
brew services start mysql


echo '\n stopping the built-in Apache';

sudo launchctl unload /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null

echo '\n Lets install Apache 2.2 with the event MPM';
brew install -v homebrew/apache/httpd22 --with-brewed-openssl --with-mpm-event

echo '\n In order to get Apache and PHP to communicate via PHP-FPM, we´ll install the mod_fastcgi module:'
brew install -v homebrew/apache/mod_fastcgi --with-brewed-httpd22

echo 'o prevent any potential problems with previous mod_fastcgi setups';

sed -i '' '/fastcgi_module/d' $(brew --prefix)/etc/apache2/2.2/httpd.conf

(export USERHOME=$(dscl . -read /Users/`whoami` NFSHomeDirectory | awk -F"\: " '{print $2}') ; export MODFASTCGIPREFIX=$(brew --prefix mod_fastcgi) ; cat >> $(brew --prefix)/etc/apache2/2.2/httpd.conf <<EOF

# Echo & Co. changes

# Load PHP-FPM via mod_fastcgi
LoadModule fastcgi_module    ${MODFASTCGIPREFIX}/libexec/mod_fastcgi.so

<IfModule fastcgi_module>
  FastCgiConfig -maxClassProcesses 1 -idle-timeout 1500

  # Prevent accessing FastCGI alias paths directly
  <LocationMatch "^/fastcgi">
    <IfModule mod_authz_core.c>
      Require env REDIRECT_STATUS
    </IfModule>
    <IfModule !mod_authz_core.c>
      Order Deny,Allow
      Deny from All
      Allow from env=REDIRECT_STATUS
    </IfModule>
  </LocationMatch>

  FastCgiExternalServer /php-fpm -host 127.0.0.1:9000 -pass-header Authorization -idle-timeout 1500
  ScriptAlias /fastcgiphp /php-fpm
  Action php-fastcgi /fastcgiphp

  # Send PHP extensions to PHP-FPM
  AddHandler php-fastcgi .php

  # PHP options
  AddType text/html .php
  AddType application/x-httpd-php .php
  DirectoryIndex index.php index.html
</IfModule>

# Include our VirtualHosts
Include ${USERHOME}/Sites/httpd-vhosts.conf
EOF
)

mkdir -pv ~/Sites/{logs,ssl}

echo 'Let´s populate the ~/Sites/httpd-vhosts.conf file';
touch ~/Sites/httpd-vhosts.conf

(export USERHOME=$(dscl . -read /Users/`whoami` NFSHomeDirectory | awk -F"\: " '{print $2}') ; cat > ~/Sites/httpd-vhosts.conf <<EOF
#
# Listening ports.
#
#Listen 8080  # defined in main httpd.conf
Listen 8443

#
# Use name-based virtual hosting.
#
NameVirtualHost *:8080
NameVirtualHost *:8443

#
# Set up permissions for VirtualHosts in ~/Sites
#
#<Directory "${USERHOME}/Sites">
#    Options Indexes FollowSymLinks MultiViews
#    AllowOverride All
#    <IfModule mod_authz_core.c>
#        Require all granted
#    </IfModule>
#    <IfModule !mod_authz_core.c>
#        Order allow,deny
#        Allow from all
#    </IfModule>
#</Directory>

# For http://localhost in the users' Sites folder
#<VirtualHost _default_:8080>
#    ServerName localhost
#    DocumentRoot "${USERHOME}/Sites"
#</VirtualHost>
#<VirtualHost _default_:8443>
#    ServerName localhost
#    Include "${USERHOME}/Sites/ssl/ssl-shared-cert.inc"
#    DocumentRoot "${USERHOME}/Sites"
#</VirtualHost>

#
# VirtualHosts
#
Include ${USERHOME}/Sites/httpd-vhosts-manual.conf
## Manual VirtualHost template for HTTP and HTTPS
#<VirtualHost *:8080>
#  ServerName project.dev
#  CustomLog "${USERHOME}/Sites/logs/project.dev-access_log" combined
#  ErrorLog "${USERHOME}/Sites/logs/project.dev-error_log"
#  DocumentRoot "${USERHOME}/Sites/project.dev"
#</VirtualHost>
#<VirtualHost *:8443>
#  ServerName project.dev
#  Include "${USERHOME}/Sites/ssl/ssl-shared-cert.inc"
#  CustomLog "${USERHOME}/Sites/logs/project.dev-access_log" combined
#  ErrorLog "${USERHOME}/Sites/logs/project.dev-error_log"
#  DocumentRoot "${USERHOME}/Sites/project.dev"
#</VirtualHost>

#
# Automatic VirtualHosts
#
# A directory at ${USERHOME}/Sites/webroot can be accessed at http://webroot.dev
# In Drupal, uncomment the line with: RewriteBase /
#

# This log format will display the per-virtual-host as the first field followed by a typical log line
LogFormat "%V %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combinedmassvhost

# Auto-VirtualHosts with .dev
<VirtualHost *:8080>
  ServerName ${EXT_SERVER_DEV}
  ServerAlias *.${EXT_SERVER_DEV}

  CustomLog "${USERHOME}/Sites/logs/${EXT_SERVER_DEV}-access_log" combinedmassvhost
  ErrorLog "${USERHOME}/Sites/logs/${EXT_SERVER_DEV}-error_log"

  VirtualDocumentRoot ${USERHOME}/Sites/%-2+
</VirtualHost>
<VirtualHost *:8443>
  ServerName ${EXT_SERVER_DEV}
  ServerAlias *.${EXT_SERVER_DEV}
  Include "${USERHOME}/Sites/ssl/ssl-shared-cert.inc"

  CustomLog "${USERHOME}/Sites/logs/${EXT_SERVER_DEV}-access_log" combinedmassvhost
  ErrorLog "${USERHOME}/Sites/logs/${EXT_SERVER_DEV}-error_log"

  VirtualDocumentRoot ${USERHOME}/Sites/%-2+
</VirtualHost>
EOF
)

echo 'Create that file-certificate and the SSL files it needs:'
(export USERHOME=$(dscl . -read /Users/`whoami` NFSHomeDirectory | awk -F"\: " '{print $2}') ; cat > ~/Sites/ssl/ssl-shared-cert.inc <<EOF
SSLEngine On
SSLProtocol all -SSLv2 -SSLv3
SSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW
SSLCertificateFile "${USERHOME}/Sites/ssl/selfsigned.crt"
SSLCertificateKeyFile "${USERHOME}/Sites/ssl/private.key"
EOF
)

openssl req \
  -new \
  -newkey rsa:2048 \
  -days 3650 \
  -nodes \
  -x509 \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=$(whoami)/CN=*.${EXT_SERVER_DEV}" \
  -keyout ~/Sites/ssl/private.key \
  -out ~/Sites/ssl/selfsigned.crt

echo 'Run apache';
brew services start httpd22

echo 'RUN WITH PORT 80';

sudo bash -c 'export TAB=$'"'"'\t'"'"'
cat > /Library/LaunchDaemons/co.echo.httpdfwd.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
${TAB}<key>Label</key>
${TAB}<string>co.echo.httpdfwd</string>
${TAB}<key>ProgramArguments</key>
${TAB}<array>
${TAB}${TAB}<string>sh</string>
${TAB}${TAB}<string>-c</string>
${TAB}${TAB}<string>echo "rdr pass proto tcp from any to any port {80,8080} -> 127.0.0.1 port 8080" | pfctl -a "com.apple/260.HttpFwdFirewall" -Ef - &amp;&amp; echo "rdr pass proto tcp from any to any port {443,8443} -> 127.0.0.1 port 8443" | pfctl -a "com.apple/261.HttpFwdFirewall" -Ef - &amp;&amp; sysctl -w net.inet.ip.forwarding=1</string>
${TAB}</array>
${TAB}<key>RunAtLoad</key>
${TAB}<true/>
${TAB}<key>UserName</key>
${TAB}<string>root</string>
</dict>
</plist>
EOF'

sudo launchctl load -Fw /Library/LaunchDaemons/co.echo.httpdfwd.plist

echo 'Install PHP';

brew install -v homebrew/php/php56

echo 'Set timezone and change other PHP settings';
(export USERHOME=$(dscl . -read /Users/`whoami` NFSHomeDirectory | awk -F"\: " '{print $2}') ; sed -i '-default' -e 's|^;\(date\.timezone[[:space:]]*=\).*|\1 \"'$(sudo systemsetup -gettimezone|awk -F"\: " '{print $2}')'\"|; s|^\(memory_limit[[:space:]]*=\).*|\1 512M|; s|^\(post_max_size[[:space:]]*=\).*|\1 200M|; s|^\(upload_max_filesize[[:space:]]*=\).*|\1 100M|; s|^\(default_socket_timeout[[:space:]]*=\).*|\1 600|; s|^\(max_execution_time[[:space:]]*=\).*|\1 300|; s|^\(max_input_time[[:space:]]*=\).*|\1 600|; $a\'$'\n''\'$'\n''; PHP Error log\'$'\n''error_log = '$USERHOME'/Sites/logs/php-error_log'$'\n' $(brew --prefix)/etc/php/5.6/php.ini)

echo 'Fix a pear and pecl permissions problem:';
chmod -R ug+w $(brew --prefix php56)/lib/php

echo 'The optional Opcache extension will speed up your PHP environment dramatically';
brew install -v php56-opcache

/usr/bin/sed -i '' "s|^\(\;\)\{0,1\}[[:space:]]*\(opcache\.enable[[:space:]]*=[[:space:]]*\)0|\21|; s|^;\(opcache\.memory_consumption[[:space:]]*=[[:space:]]*\)[0-9]*|\1256|;" $(brew --prefix)/etc/php/5.6/php.ini

echo 'Finally, let´s start PHP-FPM:';
brew services start php56

echo 'install DNSMasq';
brew install -v dnsmasq

echo 'address=/.'$EXT_SERVER_DEV'/127.0.0.1' > $(brew --prefix)/etc/dnsmasq.conf
echo 'listen-address=127.0.0.1' >> $(brew --prefix)/etc/dnsmasq.conf
echo 'port=35353' >> $(brew --prefix)/etc/dnsmasq.conf
brew services start dnsmasq
sudo mkdir -v /etc/resolver
sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/'$EXT_SERVER_DEV
sudo bash -c 'echo "port 35353" >> /etc/resolver/'$EXT_SERVER_DEV
}


function uninstall {
  echo 'Uninstall';
  echo '\n Stop services';
  sudo brew services stop httpd22
  brew services stop mysql
  brew services stop dnsmasq
  brew services stop php56

  echo '\n Uninstall services';
  brew uninstall homebrew/apache/mod_fastcgi
  sudo brew uninstall homebrew/apache/httpd22
  brew uninstall mysql
  brew uninstall php56-opcache
  brew uninstall php56
  brew uninstall dnsmasq
  rm -rf /usr/local/Cellar/httpd22

  echo '\n Unload LaunchAgents';

  sudo launchctl unload -Fw /Library/LaunchDaemons/co.echo.httpdfwd.plist
  sudo rm -f /Library/LaunchDaemons/co.echo.httpdfwd.plist
  sudo rm -f /Library/LaunchDaemons/homebrew.mxcl.httpd22.plist

  echo '\n Delete BAMP configs';
  rm -rf $(brew --prefix)/etc/apache2
  rm -rf $(brew --prefix)/etc/dnsmasq.conf
  rm -rf $(brew --prefix)/etc/my.cnf
  rm -rf $(brew --prefix)/etc/openssl
  rm -rf $(brew --prefix)/etc/php
  sudo rm -rf /etc/resolver


  echo '\n Delete Sites logs';
  rm -rf ~/Sites/httpd-vhosts.conf
  rm -rf ~/Sites/logs
  rm -rf ~/Sites/ssl
}

# Arguments

if [ "${1:-0}" = 'install' ]; then
  install
elif [ "${1:-0}" = 'uninstall' ]; then
  uninstall
elif [ "${1:-0}" = 'info' ]; then
  info
else
  echo 'add (install or uninstall)'
fi
