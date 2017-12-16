# BAMP

It is a simple script to install a environment with Apache,Mysql and PHP with Brew in a fast way.

Based on this awesome post [Alan Ivey](https://echo.co/blog/os-x-1010-yosemite-local-development-environment-apache-php-and-mysql-homebrew)

## Features

- Apache 2.2 with openssl and PHP-FPM (faster and easier to change php version)
- Php 5.6 with php56-opcache
- Mysql (Last version)

### Extras
- ~/Sites (Auto vhost, any folder in this directory is transformed into a virtualhost with the extension **.dev** without need to restart the server)
- To change php version:

```
brew services stop php56 && brew unlink php56 && brew link php54 && brew services start php54
```

## Downloading

You can grab the [script here](https://raw.githubusercontent.com/nothnk/bamp/master/bamp.sh) (Option-click to download.)

You'll need to `chmod a+x bamp.sh` in order to run it after downloading.

## Options

### Install Server.

```
./bamp.sh install
```
### Uninstall Server.
```
./bamp.sh uninstall
```

## Checking the installation

### Auto-VirtualHosts

With this command we will be able to know if the vhost machines work.

```
ping -c 3 fakedomainthatisntreal.dev
```

**NOTE** For the first time after the installation if it does not work, you should disconnect the wifi or network cable and connect it again

### Check Apache.

```
httpd -DFOREGROUND
```

### Check php

```
PHP-FPM: $(brew --prefix)/var/log/php-fpm.log
```

### Check Mysql

```
MySQL: $(brew --prefix)/var/mysql/$(hostname).err
```

## Compatibility

This script has been tested on the following versions OSX

- 10.11.4 (OSX El Capitan) | MacBook Pro (2015)


## Reference
- https://linuxconfig.org/bash-scripting-tutorial
