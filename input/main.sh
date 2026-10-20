#!/bin/bash

echo "127.0.0.1 localhost" > /etc/hosts
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

echo "#!/bin/sh" > /etc/profile.d/userland.sh
echo "unset LD_PRELOAD" >> /etc/profile.d/userland.sh
echo "unset LD_LIBRARY_PATH" >> /etc/profile.d/userland.sh
echo "export LIBGL_ALWAYS_SOFTWARE=1" >> /etc/profile.d/userland.sh
chmod +x /etc/profile.d/userland.sh

#update our repos so we can install some packages
. /etc/os-release
UBUNTU_CODENAME="$VERSION_CODENAME"
if [[ $1 = *"arm"* ]]; then
   MIRROR="http://ports.ubuntu.com/ubuntu-ports"
else
   MIRROR="http://archive.ubuntu.com/ubuntu"
fi
#noble and later ship their sources in deb822 format already
if [ ! -f /etc/apt/sources.list.d/ubuntu.sources ]; then
   echo "deb $MIRROR $UBUNTU_CODENAME main restricted universe multiverse" > /etc/apt/sources.list
   echo "deb $MIRROR $UBUNTU_CODENAME-security main restricted universe multiverse" >> /etc/apt/sources.list
   echo "deb $MIRROR $UBUNTU_CODENAME-updates main restricted universe multiverse" >> /etc/apt/sources.list
   echo "deb $MIRROR $UBUNTU_CODENAME-backports main restricted universe multiverse" >> /etc/apt/sources.list
fi
apt-get update

#install some packages with need for UserLAnd
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends sudo dropbear libgl1 libglx-mesa0 tightvncserver xterm xfonts-base twm openbox expect

#Install OpenJDK-8 and other useful tools
taskset 0x1 apt -y install iputils-ping vim wget cabextract openssh-client fontconfig openjdk-8-jre
apt -y autoremove

# Copy Microsoft TrueType core fonts
wget https://downloads.sourceforge.net/project/mscorefonts2/cabs/EUupdate.EXE
cabextract -d /usr/share/fonts/msttcore/ EUupdate.EXE
rm EUupdate.EXE

# Map font families (serif = Times, sans-serif = Arial)
cat <<EOF > /etc/fonts/local.conf
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>serif</family>
    <prefer><family>Times New Roman</family></prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Arial</family></prefer>
  </alias>
</fontconfig>
EOF

# Update the font cache
fc-cache --force

#clean up after ourselves
apt-get clean

#tar up what we have before we grow it further
tar -czvf /output/rootfs.tar.gz --exclude sys --exclude dev --exclude proc --exclude mnt --exclude etc/mtab --exclude output --exclude input --exclude .dockerenv /

#build disableselinux to go with this release
apt-get update
apt-get -y install build-essential
gcc -shared -fpic /input/disableselinux.c -o /output/libdisableselinux.so

#grab a static version of busybox that we can use to set things up later
apt-get -y install busybox-static
cp /bin/busybox output/busybox
