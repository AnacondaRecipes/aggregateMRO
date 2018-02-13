
FROM centos:5

# CentOS5 repos have been moved to vault.
# https://github.com/astj/docker-centos5-vault
COPY ./docker-centos5-vault/yum.repos.d/ /etc/yum.repos.d/

WORKDIR /tmp

# the "archive" directory will now be accessible via "/tmp/archive"
VOLUME archive

RUN yum install -y vim

RUN yum install -y fakechroot

RUN yum install -y wget curl make gcc gcc-c++ gcc-gfortran bzip2 m4 file

RUN yum install -y bzip2-devel e2fsprogs-devel texinfo

RUN wget http://www.mirrorservice.org/pub/gnu/gmp/gmp-6.1.1.tar.bz2 && tar xjvf gmp-6.1.1.tar.bz2 && \
    mkdir gmp-build && pushd gmp-build && ../gmp-6.1.1/configure --prefix=/usr && make -j32 && make install && popd && rm -rf gmp-build gmp-6.1.1 gmp-6.1.1.tar.bz2

RUN wget http://www.mpfr.org/mpfr-3.1.5/mpfr-3.1.5.tar.gz && tar xvf mpfr-3.1.5.tar.gz && \
    mkdir mpfr-build && pushd mpfr-build && ../mpfr-3.1.5/configure --prefix=/usr --with-gmp=/usr && make -j32 && make install && popd && rm -rf mpfr-3.1.5.tar.gz mpfr-3.1.5 mpfr-build

RUN wget http://www.mirrorservice.org/pub/gnu/mpc/mpc-1.0.3.tar.gz && tar xvf mpc-1.0.3.tar.gz && \
    mkdir mpc-build && pushd mpc-build && ../mpc-1.0.3/configure --prefix=/usr --with-gmp=/usr && make -j32 && make install && popd && ldconfig -v && rm -rf mpc-1.0.3.tar.gz mpc-1.0.3 mpc-build

RUN wget http://mirrors.concertpass.com/gcc/releases/gcc-5.4.0/gcc-5.4.0.tar.gz && tar xvf gcc-5.4.0.tar.gz && \
    mkdir gcc-build && \
    pushd gcc-build && \
    ../gcc-5.4.0/configure --prefix=/usr --enable-languages=c,c++,fortran --disable-multilib --with-gmp=/usr --with-mpfr=/usr --with-mpc=/usr && \
    make -j32 && \
    popd && \
    yum remove -y gcc gcc-c++ gcc-gfortran && \
    pushd gcc-build && \
    make install && \
    popd && \
    rm -rf gcc-build gcc-5.4.0.tar.gz gcc-5.4.0

RUN wget http://ftp.gnu.org/gnu/binutils/binutils-2.27.tar.gz && tar xvf binutils-2.27.tar.gz && \
    mkdir binutils-build && \
    pushd binutils-build && \
    ../binutils-2.27/configure && \
    make -j32 && \
    make install && \
    popd && \
    rm -rf binutils-2.27.tar.gz binutils-build binutils-2.27

RUN wget --no-check-certificate https://cmake.org/files/v3.6/cmake-3.6.1-Linux-x86_64.sh && \
    chmod +x cmake-3.6.1-Linux-x86_64.sh && \
    ./cmake-3.6.1-Linux-x86_64.sh --prefix=/usr --exclude-subdir && \
    rm cmake-3.6.1-Linux-x86_64.sh

RUN yum install -y gettext perl && \
    wget http://download.mono-project.com/sources/mono/mono-4.2.1.102.tar.bz2 && \
    tar xvfj mono-4.2.1.102.tar.bz2 && \
    pushd mono-4.2.1 && \
    ./configure && make -j32 && make install && \
    popd && \
    rm -rf mono-4.2.1.102.tar.bz2 mono-4.2.1

RUN wget http://mxr.mozilla.org/seamonkey/source/security/nss/lib/ckfw/builtins/certdata.txt?raw=1 && mozroots --machine --import --sync --file certdata.txt

RUN yum install -y java-1.6.0-openjdk-devel && mkdir /usr/java && ln -s /usr/lib/jvm/java-1.6.0-openjdk.x86_64 /usr/java/latest
# RUN rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-5.noarch.rpm
RUN rpm -ivh http://archives.fedoraproject.org/pub/archive/epel/epel-release-latest-5.noarch.rpm
RUN yum install -y uuid-devel zlib-devel

RUN wget "http://ftp.gnu.org/gnu/gdb/gdb-7.12.tar.gz" -O gdb-7.12.tar.gz && \
    tar xvzf gdb-7.12.tar.gz && \
    mkdir gdb-build && \
    pushd gdb-build && \
    ../gdb-7.12/configure --prefix=/usr && make -j32 && make install && \
    popd && \
    rm -fr gdb-7.12.tar.gz gdb-7.12 gdb-build

RUN curl -o platform-mpi.sh "http://mrsinfra.blob.core.windows.net/files/platform_mpi-08.3.0.0-0320r.x64.sh?st=2016-09-15T15%3A49%3A00Z&se=2020-09-16T15%3A49%3A00Z&sp=rl&sv=2015-04-05&sr=c&sig=k1JjpIJHta5RMVOlzPcWybua6BV%2BSnohEqK17Yz1gtw%3D" && \
    chmod +x platform-mpi.sh && yum install -y unzip && \
    ./platform-mpi.sh -silent && \
    echo "/opt/ibm/platform_mpi/lib/linux_amd64" > /etc/ld.so.conf.d/mpi.conf && \
    rm -f /opt/ibm/platform_mpi/lib/linux_amd64/libhpmpi.so && \
    ldconfig && ln -s /opt/ibm/platform_mpi/bin/mpiCC /usr/bin/mpiCC

RUN rm /lib64/libgcc_s.so.1 && ln -s /usr/lib64/libgcc_s.so.1 /lib64/libgcc_s.so.1 

RUN wget "http://downloads.sourceforge.net/project/ltp/Coverage%20Analysis/LCOV-1.12/lcov-1.12-1.noarch.rpm?use_mirror=kent" -O lcov-1.12-1.noarch.rpm --no-check-certificate && \
    rpm -ivh lcov-1.12-1.noarch.rpm && \
    rm -f lcov-1.12-1.noarch.rpm

RUN wget "https://www.samba.org/ftp/ccache/ccache-3.3.3.tar.bz2" -O ccache-3.3.3.tar.bz2 && \
    tar vxjf ccache-3.3.3.tar.bz2 && \
    pushd ccache-3.3.3 && \
    ./configure --prefix=/usr && make -j32 && make install && \
    popd && \
    rm -fr ccache-3.3.3 ccache-3.3.3.tar.bz2 && \
    mkdir /usr/bin/ccache-links && \
    ln -s /usr/bin/ccache /usr/bin/ccache-links/gcc && \
    ln -s /usr/bin/ccache /usr/bin/ccache-links/g++

RUN rm -fr /tmp/*

RUN yum clean all

