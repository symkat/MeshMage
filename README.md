## Setting Up Development Environment

### Debian 10

1. Install Docker

As root on a fresh Debian 10 machine, docker can be installed as follows:

```bash
apt-get remove -y docker docker-engine docker.io containerd runc
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
```

2. Install system dependancies

```bash
apt-get install -y build-essential libpq-dev libssl-dev libz-dev cpanminus liblocal-lib-perl
```


3. Add a user account with docker permissions and install public key

```bash
useradd --shell /bin/bash -m -U -G docker meshmage
echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"' >> /home/meshmage/.bashrc
mkdir /home/meshmage/.ssh
chown meshmage.meshmage /home/meshmage/.ssh
chmod 0700 /home/meshmage/.ssh
cp ~/.ssh/authorized_keys /home/meshmage/.ssh/
chown meshmage.meshmage /home/meshmage/.ssh/authorized_keys
chmod 0600 /home/meshmage/.ssh/authorized_keys
```

4. Install MeshMage

```bash
cpanm App::plx App::opan App::Dex Carton Dist::Zilla
git clone git@github.com:symkat/MeshMage.git
cd MeshMage/DB
dzil build
cd ../Web
plx --init
plx --config libspec add 00tilde.ll $HOME/perl5
plx --config libspec add 40dblib.dir ../DB/lib
plx opan add ../DB/MeshMage-DB-0.001.tar.gz
plx opan merge
plx opan carton install
```

Now you will want to copy Web/meshmage.yml.sample to Web/meshmage.yml and fill out the config file.

5. Run The App

You'll want to grab a second shell to start the DB.  Make sure you're in the top level directory of MeshMage.

```bash
meshmage@localhost:~/MeshMage$ dex db start
```

Once the database, open a third terminal to start the web server.  Make sure you're in MeshMage/Web.

```bash
meshmage@localhost:~/MeshMage/Web$ plx morbo script/meshmage_web
```

With the Web and Database running, open a fourth terminal to run the job queue.  Make sure you're in MeshMage/Web.


```bash
meshmage@localhost:~/MeshMage/Web$ plx script/meshmage_web minion worker
```


Once this has started, you can access MeshMage through port http://127.0.0.1:3000 or any other exposed IP address.  Using `morbo` will cause the Web app to reload when changes are made to the webapp.  Changes to DB/ will require the app be restarted, and changes to the Minion tasks will require the minion worker be restarted.














