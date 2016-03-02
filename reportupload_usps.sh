#!/bin/bash

# Script to upload the NCOA report file.
# -JSmith 2016-02-03

# 1.  Pass the zip filename as an argument.
#  - Still needs check to ensure .zip is lowercase, or auto-fix.

# 2.  This script assumes CSL role.  Would need to change it for AEC.
#  - It would be nice to autoset the role from the role returned by the role check subroutine.
#  - I should do that in a later version.

if [ $# -ne 1 ]; then
  { echo "Usage: $0 <Zip-filename-to-be-uploaded-to-NCOA>"; exit 1; }
fi

############################# 
# REQUIRED HELPER PROGRAMS: #
# - curl                    #
# - jq                      #
# Checks for these below    #
#############################
# jq check
which jq >/dev/null || { echo -e "ERROR!\n  -> This program requires jq >=1.4 to be installed.  Please install it before trying to run this again."; exit 1; }
jqversion=`jq --version | awk -F'-' {'print $2'}`
[ $(echo "$jqversion >= 1.4" | bc ) -eq 1 ] || { echo -e "\nERROR!!!\nThis program requires jq >=1.4 to be installed.  Please install it before trying to run this again."; exit 1; }
# curl check
which jq >/dev/null || { echo -e "ERROR!\n  -> This program requires curl to be installed.  Please install it before trying to run this again."; exit 1; }
curlversion=`curl --version | head -n 1 | awk -F" " {'print $2'}`


#############
# VARIABLES #
#############
LOGINNAME="YOURUSERNAME@HERE.com"
PASSWORD="nope"
CONTENTHEADER="-H 'Content-type: application/x-www-form-urlencoded'"

#URL BLOCK
USPSBASEURL='https://epfup.usps.gov/up/epfupld'
VERSIONURL=$USPSBASEURL/epf/version
LOGINURL=$USPSBASEURL/epf/login
LOGOUTURL=$USPSBASEURL/epf/logout
ROLESURL=$USPSBASEURL/upload/roles
HISTORYURL=$USPSBASEURL/upload/history
UPLOADURL=$USPSBASEURL/upload/file

#FILE Management
OUTPUT=/tmp/ncoa_report_outputfile
FORMFILE=/tmp/ncoa_report_binary_formfile
HEADERFILE=/tmp/ncoa_report_headerfile

#Ultimately needs to be a variable we can pass so it increments each month.
UPLOADFILENAME=$1


# Problem we face:  Every time we do something, the token rolls forward.
# We need to dump the header file to capture the change and pass it back in every time.
# Start with blank values.
tokenkey=""
logonkey=""

#### SUBROUTINES #####
usps_version(){
  echo -e "\n-----------------------\nChecking NCOA Web services version".
  curl -s $VERSIONURL | jq '.version' \
  && echo -e "Done.\n-----------------------"
}

usps_login(){
  echo -e "\n-----------------------\nLogging into the NCOA Web services".
  curl -s ${CONTENTHEADER} \
  -D $HEADERFILE \
  -X POST \
  -d "obj={\"login\":\"$LOGINNAME\",\"pword\":\"$PASSWORD\"}" \
  $LOGINURL > /dev/null \
  && echo -e "Done.\n-----------------------"
}

tokenkey_refresh(){
  # Need to refresh tokenkey after every call sent.
  tokenkey=`grep "User-Tokenkey" $1 | awk -F' ' {'print $2'} | tr -d '\r'`
}

usps_roles(){
  echo -e "\n-----------------------\nChecking NCOA Web services Roles."
  curl -s ${CONTENTHEADER} \
  -D $HEADERFILE \
  -X POST \
  -d "obj={\"tokenkey\":\"$2\",\"logonkey\":\"$1\"}" \
  $ROLESURL | jq '.roles| .[]|.type' \
  && echo -e "Done.\n-----------------------"
}

usps_history(){
  curl -s ${CONTENTHEADER} \
  -D $HEADERFILE \
  -X POST \
  -d "obj={\"tokenkey\":\"$2\",\"logonkey\":\"$1\"}" \
  $HISTORYURL | jq -r '.history|.[]' \
  && echo -e "Done.\n-----------------------"
}


# This works!
usps_upload(){
  echo -e "\n-----------------------\nUploading Report Zip file"
  curl -s \
  -D $HEADERFILE \
  -H 'Content-Type: multipart/form-data' \
  -F "role=CSL" \
  -F "logon=$1" \
  -F "token=$2" \
  -F "file=epfuploadfile" \
  -F "filename=$UPLOADFILENAME" \
  -F "epfuploadfile=@$UPLOADFILENAME" \
  $UPLOADURL \
  && echo -e "Done.\n-----------------------"
}

usps_logout(){
  # Logout
  echo -e "\n-----------------------\nLogging out...."
  curl -s ${CONTENTHEADER} \
  -X POST \
  -d "obj={\"logonkey\":\"$1\",\"tokenkey\":\"$2\"}" \
  $LOGOUTURL > /dev/null \
  && echo -e "Done.\n-----------------------"
}

cleanup(){
  echo -e "\n-----------------------\nCleaning up temp files..."
  if [ -f $OUTPUT ]; then rm -v $OUTPUT; fi
  if [ -f $HEADERFILE ]; then rm -v $HEADERFILE; fi
  if [ -f $FORMFILE ]; then rm -v $FORMFILE; fi
  echo -e "Done.\n-----------------------"
}
#### Functional Logic ####

# Login
usps_login
tokenkey_refresh $HEADERFILE
# Only have to get the logonkey once.
logonkey=`grep "User-Logonkey" $HEADERFILE | awk -F' ' {'print $2'} | tr -d '\r'`

# Print Version
usps_version

# Get roles
usps_roles $logonkey $tokenkey
tokenkey_refresh $HEADERFILE

# Get roles
echo -e "\n-----------------------\nChecking NCOA Report Upload History."
usps_history $logonkey $tokenkey
tokenkey_refresh $HEADERFILE


#Upload of file
usps_upload $logonkey $tokenkey
tokenkey_refresh $HEADERFILE

#Check that file was uploaded for paranoia
echo -e "\n-----------------------\nChecking NCOA Upload History Again to verify file was uploaded."
usps_history $logonkey $tokenkey
tokenkey_refresh $HEADERFILE

#Logout
usps_logout $logonkey $tokenkey && cleanup

#ENDOFFILE
