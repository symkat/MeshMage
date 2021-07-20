## Guide

### Installation

MeshMage can be fully installed and configured with Ansible.  From a machine with Ansible and git installed, fork MeshMage and go into the Ansible directory.

```bash
git clone https://github.com/symkat/MeshMage.git
cd MeshMage/Ansible
```

MeshMage should be installed on a Debian 10 machine.  You will need ssh access to `root@` on the target node for Ansible to access it.  Replace the IP address `10.0.0.1` with the IP address of your Debian 10 machine; don't remove the comma inside the single-quotes.

```bash
ansible-playbook -i '10.0.0.1,' playbooks/install-meshmage.yml
```

The installation process usually takes about 30 minutes to run.

### Creating the first user account

### Creating a network

### Creating a node

### Creating an SSH key

### Setting up a Linux node

### Setting up a macOS node

### Setting up a Windows node

---

## Setting Up Development Environment

### Debian 10

1. Install Docker

As root on a fresh Debian 10 machine, docker can be installed as follows:

```bash
apt-get update
apt-get remove -y docker docker-engine docker.io containerd runc
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
```

2. Install Ansible

```bash
echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" \
    > /etc/apt/sources.list.d/ansible.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
apt-get install -y ansible
```


3. Install system dependancies

```bash
apt-get install -y build-essential libpq-dev libssl-dev libz-dev cpanminus liblocal-lib-perl
```


4. Add a user account with docker permissions and install public key

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

5. Install MeshMage

The previous 4 steps were all done as root.  For this step, you'll need to login as the meshmage user.

```bash
cpanm App::plx App::opan App::Dex Carton Dist::Zilla
git clone https://github.com/symkat/MeshMage.git
cd MeshMage/DB
dzil build
cd ../Web
plx --init
plx --config libspec add 00tilde.ll $HOME/perl5
plx --config libspec add 40dblib.dir ../DB/lib
plx opan init
plx opan add ../DB/MeshMage-DB-1.tar.gz
plx opan merge
plx opan carton install
```

Now you will want to copy Web/meshmage.yml.sample to Web/meshmage.yml and fill out the config file.

```bash
cp Web/meshmage.yml.sample Web/meshmage.yml
```

6. Run The App

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




## Software Licenses Used

This project distributes binaries from [Nebula](https://github.com/slackhq/nebula/) under their MIT License, included here.

```text
MIT License

Copyright (c) 2018-2019 Slack Technologies, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```







