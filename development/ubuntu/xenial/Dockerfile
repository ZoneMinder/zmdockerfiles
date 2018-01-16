FROM ubuntu:xenial
MAINTAINER Markos Vakondios <mvakondios@gmail.com> Riley Schuit <riley.schuit@gmail.com>

# Resynchronize the package index files
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apache2 \
    build-essential \
    cmake \
    dh-autoreconf \
    dpatch \
    git \
    libapache2-mod-php \
    libarchive-zip-perl \
    libavcodec-dev \
    libavdevice-dev \
    libavfilter-dev \
    libavformat-dev \
    libavresample-dev \
    libav-tools \
    libavutil-dev \
    libbz2-dev \
    libcurl4-gnutls-dev \
    libdate-manip-perl \
    libdbd-mysql-perl \
    libdbi-perl \
    libdevice-serialport-perl \
    libgcrypt-dev \
    libgnutls-openssl-dev \
    libjpeg-turbo8 \
    libjpeg-turbo8-dev \
    libmime-lite-perl \
    libmime-perl \
    libmp4v2-dev \
    libmysqlclient-dev \
    libnet-sftp-foreign-perl \
    libnetpbm10-dev \
    libpcre3 \
    libpcre3-dev \
    libpolkit-gobject-1-dev \
    libpostproc-dev \
    libssl-dev \
    libswscale-dev \
    libsys-cpu-perl \
    libsys-meminfo-perl \
    libsys-mmap-perl \
    libtheora-dev \
    libtool \
    libv4l-dev \
    libvlc5 \
    libvlccore8 \
    libvlccore-dev \
    libvlc-dev \
    libvorbis-dev \
    libvpx-dev \
    libwww-perl \
    libx264-dev \
    mysql-client \
    mysql-server \
    php \
    php-cli \
    php-mysql \
    vlc-data \
    yasm \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --recursive https://github.com/ZoneMinder/ZoneMinder

# Change into the ZoneMinder directory
WORKDIR /ZoneMinder

# Configure ZoneMinder
RUN cmake .

# Build & install ZoneMinder
RUN make && make install

# ensure writable folders
RUN ./zmlinkcontent.sh

# Configure Apache
RUN cp misc/apache.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod -q cgi && a2enmod -q rewrite
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf && a2enconf -q servername

# Configure mysql
RUN echo "sql_mode=NO_ENGINE_SUBSTITUTION" >> /etc/mysql/mysql.conf.d/mysqld.cnf
RUN service mysql restart

# Expose http port
EXPOSE 80

VOLUME /var/lib/zoneminder/images /var/lib/zoneminder/events /var/lib/mysql /var/log/zm

# This is run each time the container is started
CMD if [ -n "$TZ" ]; then \
        echo "date.timezone = $TZ" >> /etc/php/7.0/apache2/php.ini; \
    else \
        echo "date.timezone = UTC" >> /etc/php/7.0/apache2/php.ini; \
    fi && \
    service apache2 restart && \
    if [ -n "$MYSQL_SERVER" && -n "$MYSQL_USER" &&  -n "$MYSQL_PASSWORD" && -n "$MYSQL_DB" ]; then \
        sed -i -e "s/ZM_DB_NAME=zm/ZM_DB_NAME=$MYSQL_USER/g" /etc/zm.conf && \
        sed -i -e "s/ZM_DB_USER=zmuser/ZM_DB_USER=$MYSQL_USER/g" /etc/zm.conf && \
        sed -i -e "s/ZM_DB_PASS=zm/ZM_DB_PASS=$MYSQL_PASS/g" /etc/zm.conf && \
        sed -i -e "s/ZM_DB_HOST=localhost/ZM_DB_HOST=$MYSQL_SERVER/g" /etc/zm.conf; \
    else \
        usermod -d /var/lib/mysql/ mysql && \
        service mysql restart && \
        mysql -u root < /usr/local/share/zoneminder/db/zm_create.sql; \
        mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'zmuser'@'localhost' IDENTIFIED BY 'zmpass';"; \
    fi && \
    /ZoneMinder/utils/docker/start.sh >/var/log/start.log 2>&1

################
# RUN EXAMPLES #
################

# ZoneMinder uses /dev/shm for shared memory and many users will need to increase 
# the size significantly at runtime like so:
#
# docker run -d -t -p 1080:80 \
#    --shm-size="512m"

# If you don't have seperate db:
#
# docker run -d -t -p 1080:80 \
#    -e PHP_TIMEZONE='America/Los_Angeles' \
#    -v /disk/zoneminder/events:/var/lib/zoneminder/events \
#    -v /disk/zoneminder/images:/var/lib/zoneminder/images \
#    -v /disk/zoneminder/mysql:/var/lib/mysql \
#    -v /disk/zoneminder/logs:/var/log/zm \
#    --name zoneminder \
#    zoneminder/zoneminder

# If you do have a seperate db:
#
# docker run -d -t -p 1080:80 \
#     -e PHP_TIMEZONE='America/Los_Angeles' \
#     -e ZM_DB_NAME='zmuser' \
#     -e ZM_DB_PASS='zmpassword' \
#     -e ZM_DB_NAME='zoneminder_database' \
#     -e ZM_DB_HOST='my_central_db_server' \
#     -v /disk/zoneminder/events:/var/lib/zoneminder/events \
#     -v /disk/zoneminder/images:/var/lib/zoneminder/images \
#     -v /disk/zoneminder/logs:/var/log/zm \
#     --name zoneminder \
#     zoneminder/zoneminder
