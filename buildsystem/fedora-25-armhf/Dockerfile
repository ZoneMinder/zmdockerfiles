FROM arm32v7/fedora:25
MAINTAINER Andrew Bauer <zonexpertconsulting@outlook.com>

# Fix missing locales
ENV LC_ALL="C.UTF-8" LANG="C.UTF-8"

# Enable extra repositories
RUN yum -y install \
    wget \
    curl \
    pygpgme \
    yum-utils
# RUN curl -s https://packagecloud.io/install/repositories/packpack/backports/script.rpm.sh | bash

# Install base toolset
RUN dnf -y group install 'Development Tools'
RUN dnf -y group install 'C Development Tools and Libraries'
RUN dnf -y group install 'RPM Development Tools'
RUN dnf -y install fedora-packager
RUN dnf -y install sudo git ccache cmake
RUN dnf -y update vim-minimal

# Enable cache system-wide
ENV PATH /usr/lib/ccache:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# Enable sudo without tty
RUN sed -i.bak -n -e '/^Defaults.*requiretty/ { s/^/# /;};/^%wheel.*ALL$/ { s/^/# / ;} ;/^#.*wheel.*NOPASSWD/ { s/^#[ ]*//;};p' /etc/sudoers

