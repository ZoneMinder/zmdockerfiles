FROM centos:8
MAINTAINER Andrew Bauer <zonexpertconsulting@outlook.com>

# Fix dnf best candidate failures
RUN echo "module_hotfixes=1" >> /etc/dnf/dnf.conf
RUN echo "best=0" >> /etc/dnf/dnf.conf

# Enable extra tools
RUN dnf -y install wget dnf-utils

# Enable extra repositories
RUN dnf -y install epel-release
# added PowerTools as suggested at:
#   https://fedoraproject.org/wiki/EPEL
RUN dnf config-manager --set-enabled PowerTools

# Repository for building/testing dependencies that are not present in vanilla
# CentOS and PowerTools / EPEL repositories, e.g. some Python 2 packages
# - fix missing locales
ENV LC_ALL="C" LANG="en_US.UTF-8"
# - install the backport repository
RUN curl -s https://packagecloud.io/install/repositories/packpack/backports/script.rpm.sh | bash

# Install base toolset
RUN dnf -y groupinstall 'Development Tools'
RUN dnf -y install \
    cmake \
    sudo

# Enable sudo without tty
RUN sed -i.bak -n -e '/^Defaults.*requiretty/ { s/^/# /;};/^%wheel.*ALL$/ { s/^/# / ;} ;/^#.*wheel.*NOPASSWD/ { s/^#[ ]*//;};p' /etc/sudoers
