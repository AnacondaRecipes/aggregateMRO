
FROM centos:6

WORKDIR /tmp

# the "archive" directory will now be accessible via "/tmp/archive"
VOLUME archive

RUN yum install -y vim fakechroot wget curl bzip2 file texinfo

RUN wget https://repo.continuum.io/pkgs/misc/preview/Miniconda3-4.3.31-Linux-x86_64.sh && bash \
         Miniconda3-4.3.31-Linux-x86_64.sh -bfp /opt/conda && \
         . /opt/conda/bin/activate && \
         conda install -y gcc_linux-64 gxx_linux-64 autoconf automake pkg-config libtool cmake make git perl gettext libuuid zlib && \
         echo ". /opt/conda/bin/activate" >> ~/.bashrc

RUN . /opt/conda/bin/activate && \
    wget http://download.mono-project.com/sources/mono/mono-4.2.1.102.tar.bz2 && \
    tar xvfj mono-4.2.1.102.tar.bz2 && \
    pushd mono-4.2.1 && \
    ./configure && make -j32 && make install && \
    popd && \
    rm -rf mono-4.2.1.102.tar.bz2 mono-4.2.1

RUN wget -O certdata.txt http://mxr.mozilla.org/seamonkey/source/security/nss/lib/ckfw/builtins/certdata.txt?raw=1 && mozroots --machine --import --sync --file certdata.txt

RUN yum install -y java-1.6.0-openjdk-devel && mkdir /usr/java && ln -s /usr/lib/jvm/java-1.6.0-openjdk.x86_64 /usr/java/latest
# RUN rpm -ivh http://dl.fedoraproject.org/pub/epel/epel-release-latest-5.noarch.rpm

RUN . /opt/conda/bin/activate && wget "http://ftp.gnu.org/gnu/gdb/gdb-7.12.tar.gz" -O gdb-7.12.tar.gz && \
    tar xvzf gdb-7.12.tar.gz && \
    mkdir gdb-build && \
    pushd gdb-build && \
    CXXFLAGS="$CXXFLAGS -std=c++14 -fpermissive" ../gdb-7.12/configure --prefix=/usr && make -j32 && make install && \
    popd && \
    rm -fr gdb-7.12.tar.gz gdb-7.12 gdb-build

RUN curl -o platform-mpi.sh "http://mrsinfra.blob.core.windows.net/files/platform_mpi-08.3.0.0-0320r.x64.sh?st=2016-09-15T15%3A49%3A00Z&se=2020-09-16T15%3A49%3A00Z&sp=rl&sv=2015-04-05&sr=c&sig=k1JjpIJHta5RMVOlzPcWybua6BV%2BSnohEqK17Yz1gtw%3D" && \
    chmod +x platform-mpi.sh && yum install -y unzip && \
    ./platform-mpi.sh -silent && \
    echo "/opt/ibm/platform_mpi/lib/linux_amd64" > /etc/ld.so.conf.d/mpi.conf && \
    rm -f /opt/ibm/platform_mpi/lib/linux_amd64/libhpmpi.so && \
    ldconfig && ln -s /opt/ibm/platform_mpi/bin/mpiCC /usr/bin/mpiCC

RUN wget "http://downloads.sourceforge.net/project/ltp/Coverage%20Analysis/LCOV-1.12/lcov-1.12-1.noarch.rpm?use_mirror=kent" -O lcov-1.12-1.noarch.rpm --no-check-certificate && \
    rpm -ivh lcov-1.12-1.noarch.rpm && \
    rm -f lcov-1.12-1.noarch.rpm

RUN . /opt/conda/bin/activate && wget "https://www.samba.org/ftp/ccache/ccache-3.3.3.tar.bz2" -O ccache-3.3.3.tar.bz2 && \
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
