#!/bin/bash
sudo sh <<SCRIPT

# Set up basic installation
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
apt-get upgrade -y

# Set up Docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# Install httpie
curl -SsL https://packages.httpie.io/deb/KEY.gpg | apt-key add -
curl -SsL -o /etc/apt/sources.list.d/httpie.list https://packages.httpie.io/deb/httpie.list

# Add any tools we need
apt update
apt-get install -y docker-ce git jq httpie
systemctl status docker

# Install docker-compose
# Later versions have an SSL issue on this OS
curl --fail --silent -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod a+x /usr/local/bin/docker-compose

# Add promplot
curl --fail --silent -L https://github.com/qvl/promplot/releases/download/v0.17.0/promplot_0.17.0_linux_64bit.tar.gz| tar -xz
chmod a+x ./promplot
mv -vf ./promplot  /usr/local/bin/promplot

# Add extra user
adduser perf-test
usermod -aG sudo perf-test
usermod -aG docker perf-test

chmod -R a+r /opt/fluent-bit-ci/
SCRIPT

echo "Adding $USER to docker group"
sudo usermod -aG docker "$USER"
