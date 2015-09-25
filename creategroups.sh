#!/bin/bash

# This script was built to convert qmail alias files into gmail distribution lists.
# I used gam to make this happen.
# 
# Assumptions:
# - You've renamed your .qmail-<alias> files to <alias>
# - You've ensured you have removed any procmail recipes, executable commands, etc. 
#   and all that is left is just raw local and remote email accounts


#Variables
gam='/usr/bin/python /<gam_directory>/gam.py' # Change the directory to match the path where you have gam untarred
DATADIR=/your/data/dir # The location of the directory with all of your manipulated qmail alias files

for filename in $DATADIR/* ; do
  shortname=`basename $filename`
  echo ""
  echo ""
  $gam create group $shortname name "$shortname Distribution List" description "Auto-generated DL"
  for alias in `cat $filename`; do 
    MEMBERTYPE=member
    # This next step allows you to specify a few users (you can modify it to be just one, or even many more) to be managers
    # If the line contains the username, that users alias/email address will be added as a manager.
    # Otherwise we assume they are just a generic member
    if [[ $alias == *"user1"* ]] || [[ $alias == *"user2"* ]]; then
      MEMBERTYPE=manager
    fi
    # This leaves "complete" email addresses in tact.
    # For anything else, it assumes it's a short name, and appends @domain.com to it.
    # This should probably be more intelligent, but it was enough to get the job done.
    if [[ $alias == *"@"* ]]; 
      then
        $gam update group $shortname add $MEMBERTYPE user "$alias"
      else
        $gam update group $shortname add $MEMBERTYPE user "$alias@domain.com"  # Change domain.com to your domain
    fi
  done
done
