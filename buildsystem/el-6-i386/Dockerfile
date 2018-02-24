FROM toopher/centos-i386:centos6
MAINTAINER Andrew Bauer <zonexpertconsulting@outlook.com>

# Running this first works around the following error:
# Rpmdb checksum is invalid: dCDPT(pkg checksums)
RUN yum -y install yum-utils yum-plugin-ovl; yum clean all

# Fix missing locales
RUN yum -y install glibc-common
RUN localedef -i en_US -f UTF-8 en_US.UTF-8

# Enable extra repositories
RUN yum -y update
RUN yum -y install \
    tar \
    wget \
    curl \
    pygpgme \
    yum-utils
RUN yum -y install epel-release
RUN curl -s https://packagecloud.io/install/repositories/packpack/backports/script.rpm.sh | bash
RUN yum makecache && yum clean all

# Install base toolset
RUN yum -y groupinstall 'Development Tools'
RUN yum -y install \
    epel-rpm-macros \
    cmake \
    sudo \
    vim-minimal

# Enable cache system-wide
ENV PATH /usr/lib/ccache:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# Enable sudo without tty
RUN sed -i.bak -n -e '/^Defaults.*requiretty/ { s/^/# /;};/^%wheel.*ALL$/ { s/^/# / ;} ;/^#.*wheel.*NOPASSWD/ { s/^#[ ]*//;};p' /etc/sudoers
