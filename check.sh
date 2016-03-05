#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/adobe-reader-detect.git && cd adobe-reader-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

versions2check=$(cat <<EOF
11.x
10.x
extra line
EOF
)

printf %s "$versions2check" | while IFS= read -r oneversion
do {

#retrieve all patch links for version
subversions2check=$(wget -qO- ftp://ftp.adobe.com/pub/adobe/reader/win/$oneversion/ | sed "s/\d034/\n/g" | grep "^ftp" | sed '$alast line')

#we will take each version and detect if it has installer or patch file inside
printf %s "$subversions2check" | while IFS= read -r subversion
do {

#get all english files in patch direcotry
echo $subversion

#detect if it is msi installer
installers=$(wget -qO- `echo $subversion`en_US/ | sed "s/\d034/\n/g" | grep "^ftp" | grep "AdbeRdr.*msi" | sed "s/ftp:\/\/ftp\.adobe\.com:21/http:\/\/ardownload\.adobe\.com/g" | sed '$alast line')

printf %s "$installers" | while IFS= read -r msi
do {

echo $msi | grep "AdbeRdr.*msi"
if [ $? -eq 0 ]
then

#check if this installer file is already in database
grep "$msi" $db > /dev/null
if [ $? -ne 0 ]
#if sha1 sum do not exist in database then this is new version
then
echo new installer detected!
echo

filename=$(echo $msi | sed "s/^.*\///g")
echo Downloading $msi
wget $msi -O $tmp/$filename -q
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

#lets put all signs about this file into the database
echo "$msi">> $db
echo "$md5">> $db
echo "$sha1">> $db

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$filename" "$msi 
$md5
$sha1"
} done
echo
fi

fi
} done

patches=$(wget -qO- `echo $subversion`misc/ | sed "s/\d034/\n/g" | grep "^ftp" | grep "^.*msp" | grep -v "_" | sed "s/ftp:\/\/ftp\.adobe\.com:21/http:\/\/ardownload\.adobe\.com/g" | sed '$alast line')

printf %s "$patches" | while IFS= read -r msp
do {

echo $msp | grep "^.*msp"
if [ $? -eq 0 ]
then


#check if this installer file is already in database
grep "$msp" $db > /dev/null
if [ $? -ne 0 ]
#if sha1 sum do not exist in database then this is new version
then
echo new patch file detected!
echo

filename=$(echo $msp | sed "s/^.*\///g")
echo Downloading $msp
wget $msp -O $tmp/$filename -q
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

#lets put all signs about this file into the database
echo "$msp">> $db
echo "$md5">> $db
echo "$sha1">> $db

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$filename" "$msp 
$md5
$sha1"
} done
echo
fi

fi

} done

} done
} done

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
