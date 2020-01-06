FROM knnniggett/packpack:centos-8-base
MAINTAINER Andrew Bauer <zonexpertconsulting@outlook.com>

# - fix missing locales
ENV LC_ALL="C" LANG="en_US.UTF-8"

# Apply various fixes
RUN \
    # Fix dnf best candidate failures
    echo "module_hotfixes=1" >> /etc/dnf/dnf.conf \
    && echo "best=0" >> /etc/dnf/dnf.conf \
    # Fix missing yum symlink
    && ln -sf /usr/bin/dnf /usr/bin/yum

# Enable extra tools and repositories
RUN \
    # Enable extra tools
    dnf -y install wget dnf-utils cmake sudo \
    # Install base toolset
    && dnf -y group install 'Development Tools' \
    # Enable extra repositories
    && dnf -y install epel-release \
    # Fetch and enable the RPMFusion repo
    && dnf -y localinstall --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm \
    # added PowerTools as suggested at:
    #   https://fedoraproject.org/wiki/EPEL
    && dnf config-manager --set-enabled PowerTools

# Enable sudo without tty
RUN sed -i.bak -n -e '/^Defaults.*requiretty/ { s/^/# /;};/^%wheel.*ALL$/ { s/^/# / ;} ;/^#.*wheel.*NOPASSWD/ { s/^#[ ]*//;};p' /etc/sudoers
