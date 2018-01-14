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
    libcurl4-openssl-dev \
    libdate-manip-perl \
    libdbd-mysql-perl \
    libdbi-perl \
    libdevice-serialport-perl \
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

# Setup the ZoneMinder build environment
#RUN aclocal && autoheader && automake --force-missing --add-missing && autoconf

# Configure ZoneMinder
RUN cmake .

# Build & install ZoneMinder
RUN make && make install

# ensure writable folders
RUN ./zmlinkcontent.sh

# Adding the start script
RUN cp -v utils/docker/start.sh /tmp/start.sh

# Settings rights for /usr/local/share/zoneminder/
RUN chown -R www-data:www-data /usr/local/share/zoneminder/

# Adding apache virtual hosts file
RUN cp misc/apache.conf /etc/apache2/sites-available/000-default.conf

# Expose http port
EXPOSE 80

VOLUME /var/lib/zoneminder/images /var/lib/zoneminder/events /var/lib/mysql /var/log/zm

CMD if [ ! -z "$TZ" ]; then \
			echo "date.timezone= $TZ" >> /etc/php/7.0/apache2/php.ini; \
			else \
			echo "date.timezone= America/Los_Angeles" >> /etc/php/7.0/apache2/php.ini; \
	fi && \
  if [ ! -z "$MYSQL_SERVER" && ! -z "$MYSQL_USER" &&  ! -z "$MYSQL_PASSWORD" && ! -z "$MYSQL_DB"]; then \
		sed -i -e "s/ZM_DB_NAME=zm/ZM_DB_NAME=$MYSQL_USER/g" /etc/zm.conf && \
		sed -i -e "s/ZM_DB_USER=zmuser/ZM_DB_USER=$MYSQL_USER/g" /etc/zm.conf && \
		sed -i -e "s/ZM_DB_PASS=zm/ZM_DB_PASS=$MYSQL_PASS/g" /etc/zm.conf && \
		sed -i -e "s/ZM_DB_HOST=localhost/ZM_DB_HOST=$MYSQL_SERVER/g" /etc/zm.conf; \
	else \
	  usermod -d /var/lib/mysql/ mysql && \
		service mysql restart && \
		mysql -u root -e "create database zm;" && \
		mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'zmuser'@'localhost' IDENTIFIED BY 'zmpass';"; \
		mysql -u root zm < /usr/local/share/zoneminder/db/zm_create.sql; \
	fi && \
	/ZoneMinder/utils/docker/setup.sh && \
	service apache2 restart && \
	/ZoneMinder/utils/docker/start.sh >/var/log/start.log 2>&1

# Run example if you don't have seperate db:
# docker run -d -t -p 1080:80 \
#    -e PHP_TIMEZONE='America/Los_Angeles' \
#    -v /disk/zoneminder/events:/var/lib/zoneminder/events \
#    -v /disk/zoneminder/images:/var/lib/zoneminder/images \
#    -v /disk/zoneminder/mysql:/var/lib/mysql \
#    -v /disk/zoneminder/logs:/var/log/zm \
#    --name zoneminder \
#    zoneminder/zoneminder

# Run example if you have a seperate db:
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


