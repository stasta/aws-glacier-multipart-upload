#!/bin/bash

# dependencies, jq and parallel:
# sudo dnf install jq
# sudo dnf install parallel
# sudo pip install awscli

#	Byte size to be uploaded per request
BYTE-SIZE=4194304
#	Glacier vault's name
VAULT-NAME=""	
#	Archive's description (shown on glacier console and listing)
ARCHIVE-DESCRIPTION=""

# count the number of files that begin with "part"
fileCount=$(ls -1 | grep "^part" | wc -l)
echo "Total parts to upload: " $fileCount

# get the list of part files to upload.  Edit this if you chose a different prefix in the split command
files=$(ls | grep "^part")

# initiate multipart upload connection to glacier
init=$(aws glacier initiate-multipart-upload --account-id - --part-size ${BYTE-SIZE} --vault-name ${VAULT-NAME} --archive-description ${ARCHIVE-DESCRIPTION})

echo "---------------------------------------"
# xargs trims off the quotes
# jq pulls out the json element titled uploadId
uploadId=$(echo $init | jq '.uploadId' | xargs)

# create temp file to store commands
touch commands.txt

# create upload commands to be run in parallel and store in commands.txt
i=0
for f in $files 
  do
     byteStart=$((i*${BYTE-SIZE}))
     byteEnd=$((i*${BYTE-SIZE}+${BYTE-SIZE}-1))
     echo aws glacier upload-multipart-part --body $f --range "'"'bytes '"$byteStart"'-'"$byteEnd"'/*'"'" --account-id - --vault-name ${VAULT-NAME}  --upload-id $uploadId >> commands.txt
     i=$(($i+1))
     
  done

# run upload commands in parallel
#   --load 100% option only gives new jobs out if the core is than 100% active
#   -a commands.txt runs every line of that file in parallel, in potentially random order
#   --notice supresses citation output to the console
#   --bar provides a command line progress bar
parallel --load 100% -a commands.txt --no-notice --bar

echo "List Active Multipart Uploads:"
echo "Verify that a connection is open:"
aws glacier list-multipart-uploads --account-id - --vault-name ${VAULT-NAME} 

# end the multipart upload
aws glacier abort-multipart-upload --account-id - --vault-name ${VAULT-NAME}  --upload-id $uploadId

# list open multipart connections
echo "------------------------------"
echo "List Active Multipart Uploads:"
echo "Verify that the connection is closed:"
aws glacier list-multipart-uploads --account-id - --vault-name ${VAULT-NAME} 

#echo "-------------"
#echo "Contents of commands.txt"
#cat commands.txt
echo "--------------"
echo "Deleting temporary commands.txt file"
rm commands.txt


