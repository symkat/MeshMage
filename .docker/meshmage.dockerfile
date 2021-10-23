FROM debian:11


RUN apt-get update; \
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release vim; \
    echo 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu focal main' > /etc/apt/sources.list.d/ansible.list; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367; \
    apt-get update; \
    apt-get install -y ansible git build-essential libpq-dev libssl-dev libz-dev cpanminus liblocal-lib-perl; \
    apt-get install -y postgresql-client postgresql-contrib postgresql python3-psycopg2; \
    useradd -U -s /bin/bash -m meshmage;

ADD . /home/meshmage/src
RUN chown -R meshmage:meshmage /home/meshmage/src;

USER meshmage
RUN eval $(perl -Mlocal::lib); \
    echo 'eval $(perl -Mlocal::lib)' >> /home/meshmage/.bashrc; \
    cpanm Dist::Zilla Archive::Zip; \
    cd /home/meshmage/src/DB; \
    dzil build; \
    cpanm MeshMage-DB-*.tar.gz; \
    cd /home/meshmage/src/Web; \
    cpanm --installdeps .; \
    cpanm --installdeps .; \ 
    cpanm --installdeps .;


