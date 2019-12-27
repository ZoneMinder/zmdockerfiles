FROM arm32v7/fedora:31
MAINTAINER Andrew Bauer <zonexpertconsulting@outlook.com>


# Disbale Fedora rawhide repos
RUN sed -i 's!enabled=1!enabled=0!' /etc/yum.repos.d/fedora-rawhide.repo
RUN sed -i 's!enabled=1!enabled=0!' /etc/yum.repos.d/fedora-rawhide-modular.repo

# Enable Fedora 31 release repos
RUN sed -i '0,/enabled=0/s/enabled=0/enabled=1/' /etc/yum.repos.d/fedora.repo
RUN sed -i '0,/enabled=0/s/enabled=0/enabled=1/' /etc/yum.repos.d/fedora-updates.repo

# workaround setrlimit error
RUN echo "Set disable_coredump false" >> /etc/sudo.conf

# Fix missing locales
ENV LC_ALL="C.UTF-8" LANG="C.UTF-8"

# Install base toolset
RUN dnf -y update fedora-gpg-keys --nogpgcheck
RUN dnf -y group install 'Development Tools'
RUN dnf -y group install 'C Development Tools and Libraries'
RUN dnf -y group install 'RPM Development Tools'
RUN dnf -y install fedora-packager
RUN dnf -y install sudo git ccache cmake

# Enable cache system-wide
ENV PATH /usr/lib/ccache:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# Enable sudo without tty
RUN sed -i.bak -n -e '/^Defaults.*requiretty/ { s/^/# /;};/^%wheel.*ALL$/ { s/^/# / ;} ;/^#.*wheel.*NOPASSWD/ { s/^#[ ]*//;};p' /etc/sudoers

