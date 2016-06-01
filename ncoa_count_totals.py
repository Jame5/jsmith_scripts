#!/usr/bin/python
# Quick formatting script to print out pretty reports from fixed width DAT file

import argparse # Need to be able to accept arguments

#Error handling around argument
parser = argparse.ArgumentParser(description='NCOA Reports count summary script.')
parser.add_argument('filename', metavar='N', type=str, nargs=1, help='The name of the generated .DAT report file')
args = parser.parse_args()

# Variable for file name set to argument passed at runtime
filename = str(args.filename[0])

#Initialize empty dictionary to use below
paf_counts_dict = dict()

# Open the file readonly for processing
f = open(filename,'r')

#First we iterate over the file, grabbing all count values from the lines of the report.
# We associate all the values of a given PAF id together so we can sum them below.
for line in f:
  PAFKEY = line[0:18]
  RECORDCOUNT = int(line[70:81])
  if PAFKEY in paf_counts_dict:
    paf_counts_dict[PAFKEY].append(RECORDCOUNT)
  else:
    if "<NCOAPAFHEADERIDHERE>" not in PAFKEY: 
      paf_counts_dict[PAFKEY] = [RECORDCOUNT]

# Now we print out our report.  Simple sum of the values associated with a given PAF id.
# These values are for our sum totals at the bottom of the report.
recordsum = 0
jobsum = 0

print "\n----------------------------------------------------"
print str("Final Record counts by PAF ID:").center(48)
print "----------------------------------------------------\n"

print "PAF ID:              Job Count:      Record Count:\n----------------------------------------------------"

for pafid in paf_counts_dict:
  print pafid.ljust(20),str(format(len(paf_counts_dict[pafid]), ",d")).rjust(10),str(format(sum(paf_counts_dict[pafid]), ",d")).rjust(18)
  recordsum = recordsum + sum(paf_counts_dict[pafid])
  jobsum = jobsum + len(paf_counts_dict[pafid])

print "===================================================="
print str("Grand Total").ljust(20),str(format(jobsum, ",d")).rjust(10),str(format(recordsum, ",d")).rjust(18)
print "\n\n\n"

# EOF
