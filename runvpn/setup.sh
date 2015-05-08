#!/bin/bash

##########################################################
# Notes:
# Quick setup to make this easier for other people to use.
# Still a lot of assumptions here, like the fact that you want your VPN links to be or.conf and va.conf
# Biggest one is the ability to run sudo on your own box without prompting for a password every time.
#
# Prereqs:
# openvpn is installed.
# Python (Usually installed on any given desktop linux distro
# Pip (python installer).  In ubuntu it is apt-get install python-pip
##########################################################

# Only static variable we have
WORKINGDIR=$PWD

echo -e "#########################\n# STARTING RUNVPN SETUP #\n#########################\n\n"

which pip > /dev/null || { echo "The python installer program 'pip' is not installed.  It is needed to finish setting up runvpn."; exit 1; }

# Let's make sure not just anybody can run these things.
echo "Fixing permisions since this came from a tarball."
MYUSER=`whoami`
chown -v $MYUSER:$MYUSER *
chmod -v 700 runvpn vpnstatus authtoken
chmod -v 600 username
chmod -v 644 NEO*
echo -e "Done.\n"

# Adding the username stored in the username file
echo "Please enter your LDAP username:"
read USERNAME
echo "Adding your username to the username file."
echo $USERNAME > username || { echo "The edit of username failed!"; exit 1; }
echo -e "Done.\n"

# Adding the base64 encoded password in the runvpn file
echo "Please enter your LDAP password:"
read -s USERPASSWORD
ENCRYPTEDPASSWORD=`echo ${USERPASSWORD} | base64`
echo "Adding your encrypted password to the runvpn file."
sed -i 's/USERLDAPPASSWORDHERE/'${ENCRYPTEDPASSWORD}'/' runvpn || { echo "The edit of runvpn failed!"; exit 1; }
echo -e "Done.\n"

# Adding the base64 encoded password in the runvpn file
grep AUTHTOKENHERE authtoken > /dev/null
AUTHEDIT=$?
if [ $AUTHEDIT = 1 ]; then
  echo -e "authtoken has already been edited.\n"
else
  echo "Please enter your TOTP SECRET:"
  read -s TOTPSECRET
  echo "Adding your secret to the authtoken file"
  sed -i 's/AUTHTOKENHERE/'${TOTPSECRET}'/' authtoken || { echo "The edit of authtoken failed!"; exit 1; }
  echo -e "Done.\n"
fi

# Yes, this entire block is just to install the onetimepass module
pip list | grep onetimepass > /dev/null
ONETIMEPASSINSTALLED=$?
if [ $ONETIMEPASSINSTALLED = 0 ]; then
  echo -e "onetimepass already installed.  Moving onto the configuration.\n"
else 
  echo "Installing onetimepass python module"
  sudo pip install onetimepass || { echo "The installation of onetimepass failed!"; exit 1; }
  echo -e "Done.\n"
fi

# The defaults of onetimepass is to output as an integer, which strips leading zeroes.
# This isn't useful if you always require a 6 digit numerical string, even if it starts with zero.
echo "Editing the onetimepass config file to output as a string to protect leading zeroes."
ONETIMEPASSCONFIG=`sudo find /usr/local/lib/ -name __init__.py | grep onetimepass`
sudo sed -i 's/as_string=False/as_string=True/' $ONETIMEPASSCONFIG && echo -e "Done.\n"

echo "Creating the symlinks to the config files using the openvpn standard of .conf files"
sudo ln -nsfv $WORKINGDIR/example1.ovpn /etc/openvpn/example1.conf || { echo "Failed to create symlink!"; exit 1; }
sudo ln -nsfv $WORKINGDIR/example2.ovpn /etc/openvpn/example2.conf || { echo "Failed to create symlink!"; exit 1; }
echo -e "Done.\n"

echo "Now editing config files if we haven't done so in a past run of setup.sh"
grep login.conf example1.ovpn > /dev/null
1EDIT=$?
if [ $1EDIT = 0 ]; then
  echo "example1.conf already properly edited."
else
  sed -i 's|auth-user-pass|auth-user-pass '${WORKINGDIR}/login.conf'|' example1.ovpn || { echo "Unable to modify config file!"; exit 1; }
fi

grep login.conf example2.ovpn > /dev/null
2EDIT=$?
if [ $2EDIT = 0 ]; then
  echo "example2.conf already properly edited."
else
  sed -i 's|auth-user-pass|auth-user-pass '${WORKINGDIR}/login.conf'|' example2.ovpn || { echo "Unable to modify config file!"; exit 1; }
fi
echo -e "Done!\n"

echo "All steps complete! To activate runvpn, we now create a symlink for it and vpnstatus in /usr/local/bin."
sudo ln -nsfv $WORKINGDIR/runvpn /usr/local/bin/runvpn
sudo ln -nsfv $WORKINGDIR/vpnstatus /usr/local/bin/vpnstatus
echo -e "Done!\n"
echo -e "#########################\n# RUNVPN SETUP COMPLETE #\n#########################\n\n"
