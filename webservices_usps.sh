#!/bin/bash

# Script to download USPS files
# -JSmith 2015-09-30

############################# 
# REQUIRED HELPER PROGRAMS: #
# - curl                    #
# - jq                      #
# Checks for these below    #
#############################
# jq check
echo "Checking for jq installation..."
which jq >/dev/null || { echo -e "ERROR!\n  -> This program requires jq >=1.4 to be installed.  Please install it before trying to run this again."; exit 1; }
jqversion=`jq --version | awk -F'-' {'print $2'}`
[ $(echo "$jqversion >= 1.4" | bc ) -eq 1 ] || { echo -e "\nERROR!!!\nThis program requires jq >=1.4 to be installed.  Please install it before trying to run this again."; exit 1; }
echo "jq version $jqversion OK."
# curl check
echo "Checking for curl installation..."
which jq >/dev/null || { echo -e "ERROR!\n  -> This program requires curl to be installed.  Please install it before trying to run this again."; exit 1; }
curlversion=`curl --version | head -n 1 | awk -F" " {'print $2'}`
echo "curl version $curlversion OK."


#############
# VARIABLES #
#############
# Edit as needed
LOGINNAME=""
PASSWORD=""
CONTENTHEADER="-H \"Content-type: application/x-www-form-urlencoded\""
LASTWEEK=`date --date="6 days ago" +%Y-%m-%d`

#URL BLOCK
USPSBASEURL='https://epfws.usps.gov/ws/resources'
LOGINURL=$USPSBASEURL/epf/login
LISTURL=$USPSBASEURL/download/list
STATUSURL=$USPSBASEURL/download/status
DOWNLOADLISTURL=$USPSBASEURL/download/dnldlist
LISTPLUSURL=$USPSBASEURL/download/listplus
FILEDOWNLOADURL=$USPSBASEURL/download/file
LOGOUTURL=$USPSBASEURL/epf/logout

#FILE Management
PRODUCTCODE= # Example: NCAW
PRODUCTID=   # Example: NCL18H
OUTPUT=/tmp/outputfile
HEADERFILE=/tmp/headerfile
TEMPFILENAME=tempfile_output.tar


# Problem we face:  Every time we do something, the token rolls forward.
# We need to dump the header file to capture the change and pass it back in every time.
# Start with blank values.
tokenkey=""
logonkey=""

#### SUBROUTINES #####
usps_login(){
  echo -e "\n-----------------------\nLogging into the USPS Web services".
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

get_filelist(){
  echo -e "\n-----------------------\nChecking for available files to download."
  curl -s ${CONTENTHEADER} \
  -D $HEADERFILE \
  -X POST \
  -d "obj={\"tokenkey\":\"$1\",\"logonkey\":\"$2\",\"productcode\":\"$PRODUCTCODE\",\"productid\":\"$PRODUCTID\",\"status\":\"SNX\"}" \
  $LISTURL > $OUTPUT \
  && echo -e "Done."
}

statusupdate(){
  # Set an old file status to C for completed
  curl -s ${CONTENTHEADER} \
  -D $HEADERFILE \
  -X POST \
  -d "obj={\"tokenkey\":\"$1\",\"logonkey\":\"$2\",\"newstatus\":\"$3\",\"fileid\":\"$4\"}" \
  $STATUSURL > /dev/null
}

usps_logout(){
# Logout
echo -e "\n-----------------------\nLogging out...."
curl -s ${CONTENTHEADER} \
-X POST \
-d "obj={\"logonkey\":\"$2\",\"tokenkey\":\"$1\"}" \
$LOGOUTURL > /dev/null \
&& echo -e "Done.\n-----------------------"
}

cleanup(){
  echo -e "\n-----------------------\nCleaning up temp files..."
  if [ -f $OUTPUT ]; then rm -v $OUTPUT; fi
  if [ -f $TEMPFILENAME ]; then rm -v $TEMPFILENAME; fi
  if [ -f $HEADERFILE ]; then rm -v $HEADERFILE; fi
  echo -e "Done.\n-----------------------"
}

#### Functional Logic ####

# STEP 1: Login and obtain our logonkey value and tokenkey's initial value.
usps_login #Need some way to capture login result and exit if it fails.
tokenkey_refresh $HEADERFILE
# Only set logonkey once.  It is the same for the entire session.
logonkey=`grep "User-Logonkey" $HEADERFILE | awk -F' ' {'print $2'} | tr -d '\r'`

# STEP 2: Get list of files
get_filelist $tokenkey $logonkey
tokenkey_refresh $HEADERFILE

# STEP 3:  Extract values from the file listing.  Inform user of status.
MATCHEDFILE=`cat $OUTPUT | jq --arg date "$LASTWEEK" -r '.fileList| .[] | select(.fulfilled >=$date) | join (",")'`
  #Error checking
[ "$MATCHEDFILE" != "" ] || { echo -e "No valid file IDs found that matched our criteria.  Dumping raw JSON output and exiting."; usps_logout $tokenkey $logonkey ; echo -e "\n===RAW JSON RESPONSE FILE===\n"; cat $OUTPUT; echo ""; cleanup; exit 0; }

#Take the $MATCHEDFILE CSV value and set the variables needed below.
FILEID=`echo "$MATCHEDFILE" | awk -F',' '{print $1}'`
FILESTATUS=`echo "$MATCHEDFILE" | awk -F',' '{print $2}'`
FILEPATH=`echo "$MATCHEDFILE" | awk -F',' '{print $3}'`
FILEDATE=`echo "$MATCHEDFILE" | awk -F',' '{print $4}'`

echo -e "\n-----------------------\n!!   MATCH FOUND   !!\nFile $FILEID was posted on ${FILEDATE}."

if [ "$FILESTATUS" = "N" ]; then
  echo -e "File $FILEID is a new file for this week with status ($FILESTATUS). Proceeding to download the file."
elif [ "$FILESTATUS" = "X" ]; then
  echo -e "File $FILEID has a status of (${FILESTATUS}). This usually indicates we were unable to extract the file after downloading. Attempting to re-download now."
elif [ "$FILESTATUS" = "S" ]; then
  echo -e "File $FILEID has a status of (${FILESTATUS}). Since the download hasn't started yet, this usually means something bad happened during the last attempt."
fi
echo -e "-----------------------"

# STEP 4: Set File status to Downloading (S).
echo -e "\n-----------------------\nSetting file status for $FILEID to S and starting download."
statusupdate $tokenkey $logonkey S $FILEID
tokenkey_refresh $HEADERFILE
echo -e "Done.\n-----------------------"

# STEP 5: Download the File.
echo -e "\n-----------------------\nNow downloading file ID#:$FILEID from the Akamai CDN.\n"

curl -o $TEMPFILENAME \
-D $HEADERFILE \
-H "Content-type: application/x-www-form-urlencoded" \
-H "Akamai-File-Request: $FILEPATH" \
-H "tokenkey: $tokenkey" \
-H "logonkey: $logonkey" \
-H "fileid: $FILEID" \
-X POST \
-d "obj={\"logonkey\":\"$logonkey\",\"tokenkey\":\"$tokenkey\",\"fileid\":\"$FILEID\"}" \
$FILEDOWNLOADURL

tokenkey_refresh $HEADERFILE
echo -e "Done.\n-----------------------"

# STEP 6: Check the file.  
echo -e "\n-----------------------\nChecking the file integrity...\n"
tar -tf $TEMPFILENAME >/dev/null || { echo -e "\nERROR OCCURED!\nFAILED TO VALIDATE TAR FILE!\nMarking File Download Failed (X)!\nPlease Rerun the script to try again."; statusupdate $tokenkey $logonkey X $FILEID; tokenkey_refresh $HEADERFILE; usps_logout $tokenkey $logonkey; cleanup;  exit 1; }
echo -e "File integrity checks out.  Setting file status to (C) for Complete."
statusupdate $tokenkey $logonkey C $FILEID
tokenkey_refresh $HEADERFILE
echo -e "Done.\n-----------------------"

# Step 7: Logout and clean up temp files.
usps_logout $tokenkey $logonkey
cleanup
