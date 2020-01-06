FROM arm32v7/fedora:30
MAINTAINER Andrew Bauer <zonexpertconsulting@outlook.com>

# Disbale Fedora updates-testing repos
RUN sed -i 's!enabled=1!enabled=0!' /etc/yum.repos.d/fedora-updates-testing.repo
RUN sed -i 's!enabled=1!enabled=0!' /etc/yum.repos.d/fedora-updates-testing-modular.repo

# workaround setrlimit error
RUN echo "Set disable_coredump false" >> /etc/sudo.conf

# Fix missing locales
ENV LC_ALL="C.UTF-8" LANG="C.UTF-8"

# Install base toolset
RUN dnf -y group install 'Development Tools'
RUN dnf -y group install 'C Development Tools and Libraries'
RUN dnf -y group install 'RPM Development Tools'
RUN dnf -y install fedora-packager
RUN dnf -y install sudo git ccache cmake

# Enable cache system-wide
ENV PATH /usr/lib/ccache:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# Enable sudo without tty
RUN sed -i.bak -n -e '/^Defaults.*requiretty/ { s/^/# /;};/^%wheel.*ALL$/ { s/^/# / ;} ;/^#.*wheel.*NOPASSWD/ { s/^#[ ]*//;};p' /etc/sudoers

