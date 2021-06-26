#!/bin/bash

if [ $UID -ne 0 ];
then
    echo "Error: Must be root, please invoke with:"
    echo "sudo $0"
    exit -1
fi

echo "Copying files..."
test -d /etc/nebula || mkdir /etc/nebula
cp *.crt *.key /etc/nebula
cp *.yml /etc/nebula/config.yml
cp nebula /usr/local/bin/
chmod 750 /usr/local/bin/nebula
cp Nebula.plist /Library/LaunchDaemons/ 

echo "Loading launchd service..."
launchctl load /Library/LaunchDaemons/Nebula.plist

echo "Done!"
