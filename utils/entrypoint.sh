#!/bin/bash
# ZoneMinder Dockerfile entrypoint script
# Written by Andrew Bauer <zonexpertconsulting@outlook.com>
#
# This script will start mysql, apache, and zoneminder services.
# It looks in common places for the files & executables it needs
# and thus should be compatible with major Linux distros.

###############
# SUBROUTINES #
###############

# Find ciritical files and perform sanity checks
initialize () {

    # Check to see if this script has access to all the commands it needs
    for CMD in cat grep install ln my_print_defaults mysql mysqladmin mysqld_safe sed sleep su tail usermod; do
      type $CMD &> /dev/null

      if [ $? -ne 0 ]; then
        echo
        echo "ERROR: The script cannot find the required command \"${CMD}\"."
        echo
        exit 1
      fi
    done

    # Look in common places for the apache executable commonly called httpd or apache2
    for FILE in "/usr/sbin/httpd" "/usr/sbin/apache2"; do
        if [ -f $FILE ]; then
            HTTPBIN=$FILE
            break
        fi
    done

    # Look in common places for the zoneminder config file - zm.conf
    for FILE in "/etc/zm.conf" "/etc/zm/zm.conf" "/usr/local/etc/zm.conf" "/usr/local/etc/zm/zm.conf"; do
        if [ -f $FILE ]; then
            ZMCONF=$FILE
            break
        fi
    done

    # Look in common places for the zoneminder startup perl script - zmpkg.pl
    for FILE in "/usr/bin/zmpkg.pl" "/usr/local/bin/zmpkg.pl"; do
        if [ -f $FILE ]; then
            ZMPKG=$FILE
            break
        fi
    done

    # Look in common places for the zoneminder dB creation script - zm_create.sql
    for FILE in "/usr/share/zoneminder/db/zm_create.sql" "/usr/local/share/zoneminder/db/zm_create.sql"; do
        if [ -f $FILE ]; then
            ZMCREATE=$FILE
            break
        fi
    done

    # Look in common places for the php.ini relevant to zoneminder - php.ini
    # Search order matters here because debian distros commonly have multiple php.ini's
    for FILE in "/etc/php/7.0/apache2/php.ini" "/etc/php5/apache2/php.ini" "/etc/php.ini" "/usr/local/etc/php.ini"; do
        if [ -f $FILE ]; then
            PHPINI=$FILE
            break
        fi
    done

    for FILE in $ZMCONF $ZMPKG $ZMCREATE $PHPINI $HTTPBIN; do 
        if [ -z $FILE ]; then
            echo
            echo "FATAL: This script was unable to determine one or more cirtical files. Cannot continue."
            echo
            echo "VARIABLE DUMP"
            echo "-------------"
            echo
            echo "Path to zm.conf: ${ZMCONF}"
            echo "Path to zmpkg.pl: ${ZMPKG}"
            echo "Path to zm_create.sql: ${ZMCREATE}"
            echo "Path to php.ini: ${PHPINI}"
            echo "Path to Apache executable: ${HTTPBIN}"
            echo
            exit 98
        fi
    done
}

# Usage: get_mysql_option SECTION VARNAME DEFAULT
# result is returned in $result
# We use my_print_defaults which prints all options from multiple files,
# with the more specific ones later; hence take the last match.
get_mysql_option (){
        result=`my_print_defaults "$1" | sed -n "s/^--$2=//p" | tail -n 1`
        if [ -z "$result" ]; then
            # not found, use default
            result="$3"
        fi
}

# Return status of mysql service
mysql_running () {
    mysqladmin ping > /dev/null 2>&1
    local result="$?"
    if [ "$result" -eq "0" ]; then
        echo "1" # mysql is running
    else
        echo "0" # mysql is not running
    fi
}

# Blocks until mysql starts completely or timeout expires
mysql_timer () {
    timeout=60
    count=0
    while [ "$(mysql_running)" -eq "0" ] && [ "$count" -lt "$timeout" ]; do
        sleep 1 # Mysql has not started up completely so wait one second then check again
        count=$((count+1))
    done

    if [ "$count" -ge "$timeout" ]; then
       echo " * Warning: Mysql startup timer expired!"
    fi
}

mysql_datadir_exists() {
    if [ -d /var/lib/mysql/mysql ]; then
        echo "1" # datadir exists
    else
        echo "0" # datadir does not exist
    fi
}

# mysql service management
start_mysql () {
    # determine if we are running mariadb or mysql then guess pid location
    if [ $(mysql --version |grep -ci mariadb) -ge "1" ]; then
        default_pidfile="/var/run/mariadb/mariadb.pid"
    else
        default_pidfile="/var/run/mysqld/mysqld.pid"
    fi

    # verify our guessed pid file location is right
    get_mysql_option mysqld_safe pid-file $default_pidfile
    mypidfile=$result
    mypidfolder=${mypidfile%/*}
    mysocklockfile=${mypidfile%/mysqld.sock.lock}

    if [ "$(mysql_datadir_exists)" -eq "0" ]; then
        echo -n " * First run of MYSQL, initializing DB."
        mysqld --initialize-insecure
    elif [ -e ${mypidsocklock} ]; then
        echo -n " * Removing stale lock file"
        rm -f ${mypidsocklock}
    fi
    # Start mysql only if it is not already running
    if [ "$(mysql_running)" -eq "0" ]; then
        echo -n " * Starting MySQL database server service"
        test -e $mypidfolder || install -m 755 -o mysql -g root -d $mypidfolder
        mysqld_safe --user=mysql --timezone="$TZ" > /dev/null 2>&1 &
        RETVAL=$?
        if [ "$RETVAL" = "0" ]; then
            echo "   ...done."
            mysql_timer # Now wait until mysql finishes its startup
        else
            echo "   ...failed!"
        fi
    else
        echo " * MySQL database server already running."
    fi

    mysqlpid=`cat "$mypidfile" 2>/dev/null`    
}

# Apache service management
start_http () {
    echo -n " * Starting Apache http web server service"
    # Debian requires we load the contents of envvars before we can start apache
    if [ -f /etc/apache2/envvars ]; then
        source /etc/apache2/envvars
    fi
    $HTTPBIN -k start  > /dev/null 2>&1
    RETVAL=$?
    if [ "$RETVAL" = "0" ]; then
        echo "   ...done."
    else
        echo "   ...failed!"
    fi
}

# ZoneMinder service management
start_zoneminder () {
    echo -n " * Starting ZoneMinder video surveillance recorder"
    $ZMPKG start > /dev/null 2>&1
    RETVAL=$?
    if [ "$RETVAL" = "0" ]; then
        echo "   ...done."
    else
        echo "   ...failed!"
    fi
}

cleanup () {
    echo " * SIGTERM received. Cleaning up before exiting..."
    kill $mysqlpid > /dev/null 2>&1
    $HTTPBIN -k stop > /dev/null 2>&1
    sleep 5
}

################
# MAIN PROGRAM #
################

echo
initialize

# Set the timezone before we start any services
if [ -z "$TZ" ]; then
    $TZ = UTC
fi
echo "date.timezone = $TZ" >> $PHPINI
if [ -L /etc/localtime ]; then
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
fi
if [ -f /etc/timezone ]; then
    echo "$TZ" > /etc/timezone
fi

chown -R mysql:mysql /var/lib/mysql/
# Configure then start Mysql
if [ -n "$MYSQL_SERVER" ] && [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ] && [ -n "$MYSQL_DB" ]; then
    sed -i -e "s/ZM_DB_NAME=zm/ZM_DB_NAME=$MYSQL_USER/g" $ZMCONF
    sed -i -e "s/ZM_DB_USER=zmuser/ZM_DB_USER=$MYSQL_USER/g" $ZMCONF
    sed -i -e "s/ZM_DB_PASS=zm/ZM_DB_PASS=$MYSQL_PASS/g" $ZMCONF
    sed -i -e "s/ZM_DB_HOST=localhost/ZM_DB_HOST=$MYSQL_SERVER/g" $ZMCONF
    start_mysql
else
    usermod -d /var/lib/mysql/ mysql
    datadirexists=$(mysql_datadir_exists)
    start_mysql
    if [ ${datadirexists} -eq "0" ]; then
        echo " * First run of mysql in the container, creating zoneminder tables."
        mysql -u root < $ZMCREATE
    else
        echo " * Not the first run, skipping table creation."
    fi
    mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'zmuser'@'localhost' IDENTIFIED BY 'zmpass';"
fi

# Ensure we shutdown our services cleanly when we are told to stop
trap cleanup SIGTERM

# Start Apache
start_http

# Start ZoneMinder
start_zoneminder

# Stay in a loop to keep the container running
while :
do
    # perhaps output some stuff here or check apache & mysql are still running
    sleep 3600
done

