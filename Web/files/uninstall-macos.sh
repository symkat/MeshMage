#!/bin/bash

if [ $UID -ne 0 ];
then
    echo "Error: Must be root, please invoke with:"
    echo "sudo $0"
    exit -1
fi

launchctl unload /Library/LaunchDaemons/Nebula.plist
rm -fr /etc/nebula
rm /usr/local/bin/nebula
rm /Library/LaunchDaemons/Nebula.plist

echo "Done!"
