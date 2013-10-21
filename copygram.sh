#!/bin/bash

#title           :copygram.sh
#description     :This script will backup photos from http://instagr.am
#author		 	 :Magnus Janson <magnus@copygr.am>
#date            :20110205
#version         :0.4
#usage		 	 :bash copygram.sh <username> <email> <options> <ip> <make-zip> <future-news> <user_id> <user_token>

clear

###########################
############## CONF
###########################

# > Script settings
scriptname="Copygr.am"
version=0.4
usage="copygram.sh <username> <email> <options> <ip> <make-zip> <future-news> <user_id> <user_token>"

# > Print header
printf "### $scriptname %s\n" "$version"

# > Variables that must be set to run the script
username=$1
email=$2
options=$3
webrequestip=$4
makezip=$5
futurenews=$6
user_id=$7
user_token=$8
limit=$9

date=$(date +%m%d%y_%H%M)
archivedate=$(date +%m%d%y_%H%M%S)
logdate=$(date +%Y-%m-%d\ %H:%M:%S)

# > Make sure that variables needed to run the the script is set
if [[ -z "$username" || -z "$email" || -z "$user_token" ]]; then
printf "\n[WARN] Insufficient parameters!\n[INFO] Usage: %s\n" "$usage"
exit
fi

# > Make sure that working directories exist
if [ ! -d "copys" ]; then
mkdir copys
fi

if [ ! -d "photos/$username" ]; then
mkdir photos/$username/
fi


# > Instagram API config variables
client_id="fje2d64a8534f41ccbbcxdc307448f95a"
client_secret="2843769c169f43f1bb5566036e113ea"
redirect_uri="http://localhost:8312/blackhole/"

# > Instagram user variables
instagram_username="copygramdev"
instagram_password="ohXe3phoSuqu3vei"

# > Instagram API url variables
login_url="https://instagram.com/accounts/login/"
auth_url_code="http://instagram.com/oauth/authorize/?client_id=$client_id&redirect_uri=$redirect_uri&response_type=code"
auth_url_token="http://instagram.com/oauth/authorize/?client_id=$client_id&redirect_uri=$redirect_uri&response_type=token"
token_url="https://api.instagram.com/oauth/access_token"
user_search="https://api.instagram.com/v1/users/search?"
user_recent="https://api.instagram.com/v1/users"

# > MySQL Logging
sql_username="copygram"
sql_password="Equ2agh9uid0Aidi"
sql_db="cglog"

# > For debugging purposes only, empty log for each exec
#/usr/bin/mysql -u$sql_username -p$sql_password -D$sql_db -e "delete from mainlog" >> /dev/null

###########################
############## FUNCTIONS
###########################
log(){
sql_query=$1
/usr/bin/mysql -u$sql_username -p$sql_password -D$sql_db -e "$sql_query" >> /dev/null
}

instagram_login(){
# $login_url $instagram_username $instagram_password $username
curl -o /dev/null -s -S -f -k -L -b instawebcookie -c instawebcookie -F "username=$2" -F "password=$3" $1
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','INSTAGRAM','$username','instagram_login','','$1','$webrequestip')"
}

instagram_authorize_and_request_token(){
# $auth_url_token $username
token=`curl -s -S -f -k -i -b instawebcookie -c instawebcookie -d "allow=Yes" $1 | awk -F'=' '/access_token=/ {print $NF}' | tr -d '\015'`
if [[ -z "$token" ]]; then
printf "token_not_fetched"
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'ERROR','SCRIPT','WEB','$username','instagram_authorize_and_request_token','token_not_fetched','$1','$webrequestip')"
exit
fi
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','WEB','$username','instagram_authorize_and_request_token','$token','$1','$webrequestip')"
}

instagram_get_user_id(){
#$user_search $username $token
user_id=`curl -s -S $1"q="$2"&access_token="$3 | awk -F"\"" '{print $22}'`
if [[ -z "$user_id" ]]; then
printf "user_id_not_found"
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'ERROR','SCRIPT','WEB','$username','instagram_get_user_id','user_id_not_found','$1','$webrequestip')"
exit
fi
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','INSTAGRAM','$username','instagram_get_user_id','$user_id','$1','$webrequestip')"
}

validate_public_stream(){
#$user_recent $user_id $token
validate=`curl -s -S $1/$2"/media/recent/?access_token="$3"&count=60" | gawk -F': "' '/error_message/ gsub(/"}}/,""){ print $NF }'`
if [[ "$validate" == "you cannot view this resource" ]]; then
printf "[$4 $5] the stream for user $2 is not public\n"
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'ERROR','SCRIPT','WEB','$username','validate_public_stream','stream_not_public','$1','$webrequestip')"
exit
fi
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','INSTAGRAM','$username','validate_public_stream','$validate','$1','$webrequestip')"
}

instagram_get_photos(){

next_url=$1/$2"/media/recent/?access_token="$3"&count=60"
photo_batch_counter=1
next_max_id=null

while [ ! $next_max_id = "media" ]; do
printf "\n[$scriptname]  Fetching photo batch $photo_batch_counter"
let photo_batch_counter++
wget -i - -q -O | curl -s -S $next_url | awk -F"," -v k="_7.jpg" '
	{
		for(i=1;i<=NF;i++)
		{
			if($i ~ k)
			{
				{
				gsub(/\"standard_resolution\"\:\{\"url\"\:\"*\"/,"",$i); printf("%s", $i)
				}
			}
		}
	}' photos/$username/$i.jpg
next_max_id=`curl -s -S $1/$2"/media/recent/?access_token="$3"&count=60&max_id=$next_max_id" | awk -F '\"' '{print $10}'`
next_url=$1/$2"/media/recent/?access_token="$3"&count=60&max_id=$next_max_id"
done



#instagram_get_photos $user_recent $user_id $token
while [ -z "$next_max_id" ]; do
next_max_id=`curl -s -S $1/$2"/media/recent/?access_token="$3"&count=60&max_id=$next_max_id" | awk -F '\"' '{print $10}'`
next_url=$1/$2"/media/recent/?access_token="$3"&count=60&max_id=$next_max_id"
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','INSTAGRAM','$username','instagram_get_photos','$1/$2/media/recent/?access_token=$3&count=60&max_id=$next_max_id','$next_url','$webrequestip')"
done
}

count_photos(){
photocount=`find photos/$username -type f | wc -l`
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','SHELL','$username','count_photos','$photocount','photos/$username/*','$webrequestip')"
}

rename_photos(){
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','SHELL','$username','rename_photos','','photos/$username/*','$webrequestip')"
for file in photos/$username/*.jpg
do
   modifdate=`stat -c %y $file`
   formatdate=`date -d "$modifdate" "+%Y%m%d_%0k%M%S"`
   filecut=`echo $file | cut -d "/" -f3`
   mv $file photos/$username/$formatdate"_"$filecut
done
}

generate_html_example(){
next_url=$1/$2"/media/recent/?access_token="$3"&count=60"
photo_batch_counter=1
next_max_id=null

htmlstart="<html>
<head>
 <title>Copygram - "$username"</title>
 </head>
 <body style=\"margin:0px; padding:0px;\">
"

printf "%b\n" "$htmlstart" >> photos/$username/index.html

while [ ! $next_max_id = "tags" ]; do
#printf "\n[$scriptname]  Fetching photo batch $photo_batch_counter"
let photo_batch_counter++
curl -s -S $next_url | awk -F"," -v k="_7.jpg" '
	{
		for(i=1;i<=NF;i++)
		{
			if($i ~ k)
			{
				{
				gsub(/\"standard_resolution\"\:\{\"url\"\:\"*\"/,"",$i);gsub(/\"/,"",$i); printf("<img src=\"%s\" width=\"300\" height=\"300\" style=\"margin:0px; padding:0 px;\"/>", $i)
				}
			}
		}
	}' >> photos/$username/index.html
next_max_id=`curl -s -S $1/$2"/media/recent/?access_token="$3"&count=60&max_id=$next_max_id" | awk -F '\"' '{print $10}'`
next_url=$1/$2"/media/recent/?access_token="$3"&count=60&max_id=$next_max_id"
done

htmlend="</body>
</html>"

printf "%b\n" "$htmlend" >> photos/$username/index.html

log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','SHELL','$username','generate_html_example','','photos/$username/index.html','$webrequestip')"

}

create_grid(){
if [ ! -d "$username" ]; then
mkdir $username
fi
cp photos/$username/index.html $username/index.html
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','SHELL','$username','create_grid','','$username/index.html','$webrequestip')"
}

create_archive(){
archivename=$archivedate"_"$username"_"$scriptname".zip"
folder2archive="photos/$scriptname_"$username
zip -q -r "copys/"$archivename $folder2archive
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','SHELL','$username','create_archive','','copys/$archivename','$webrequestip')"
}

delete_downloaded_photos(){
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SCRIPT','SHELL','$username','delete_downloaded_photos','','photos/$username/','$webrequestip')"
rm -rf photos/$username/
}

send_mail(){
if [[ "$makezip" = "make-zip" && "$futurenews" = "future-news" ]]; then
mailtofrom="To: $email
From: Copygram <hello@copygr.am>"
mailfoot="Best Regards,
$scriptname team
http://copygr.am"

action="make_zip_future_news"
mailurl="http://copygr.am/copys/$archivename;http://copygr.am/$username"
mailsubject="Subject: Thanks for using Copygram Back-Up! "
mailbody="Your Instagram archive is now available for download at http://copygr.am/copys/$archivename

Your archive will be available for 2 hours, counting from the time when this email was sent. For your security, the folder will be deleted from our servers after this time limit has been reached.

Remember that you can always view or share the latest grams for $username by visiting http://copygr.am/$username, or even turn them into analog photo prints in our print shop at http://shop.copygr.am!

"
fi

if [[ "$makezip" = "null" && "$futurenews" = "future-news" ]]; then
mailtofrom="To: $email
From: Copygram <hello@copygr.am>"
mailfoot="Best Regards,
$scriptname team
http://copygr.am"

action="future_news"
mailurl="http://copygr.am/copys/$archivename;http://copygr.am/$username"
mailsubject="Subject: You registered for future news!"
mailbody="Thank you for registering for future news!

Remember that you can always view or share the latest grams for $username by visiting http://copygr.am/$username"
fi

if [[ "$makezip" = "make-zip" && "$futurenews" = "null" ]]; then
mailtofrom="To: $email
From: Copygram <hello@copygr.am>"
mailfoot="Best Regards,
$scriptname team
http://copygr.am"

action="make_zip"
mailurl="http://copygr.am/copys/$archivename;http://copygr.am/$username"
mailsubject="Subject: Thanks for using Copygram Back-Up! "
mailbody="Your Instagram archive is now available for download at http://copygr.am/copys/$archivename

Your archive will be available for 2 hours, counting from the time when this email was sent. For your security, the folder will be deleted from our servers after this time limit has been reached.

Remember that you can always view or share the latest grams for $username by visiting http://copygr.am/$username, or even turn them into analog photo prints in our print shop at http://shop.copygr.am!

"
fi

printf "%b\n" "$mailtofrom \n$mailsubject \n\nHi! \n\n$mailbody \n\n$mailfoot" | /usr/sbin/sendmail $email

log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','SHELL','MAIL','$username','$email','','$mailurl','$webrequestip')"
}

###########################
############## MAIN
###########################

#printf "\n[$scriptname] user requested a copy from the website form
log "INSERT INTO mainlog (id, datetime, type, source, target, username, action, reply, url, web_request_ip) VALUES (NULL, CURRENT_TIMESTAMP, 'INFO','WEB','SCRIPT','$username','web_copy_request','','http://copygr.am/','$webrequestip')"

#Check if we only want to validate the username, public stream and instagram online
if [[ "$options" = "validate" ]]; then
	instagram_authorize_and_request_token $auth_url_token $username
	instagram_get_user_id $user_search $username $token
	validate_public_stream $user_recent $user_id $token
exit
fi

#printf "\n[$scriptname] Logging in to instagram and saving cookie"
instagram_login $login_url $instagram_username $instagram_password 

#printf "\n[$scriptname] Authorize script and request token"
instagram_authorize_and_request_token $auth_url_token $username

#printf "\n[$scriptname] Get user id for $username"
instagram_get_user_id $user_search $username $token
printf "\n[$scriptname]  $username has user id $user_id"

if [[ "$makezip" = "make-zip" ]]; then
#printf "\n[$scriptname] Get photos"
instagram_get_photos $user_recent $user_id $user_token

#printf "\n[$scriptname] Count number of downloaded photos"
count_photos photos/$username

#printf "\n[$scriptname] Add modified date/time to photos filename"
rename_photos photos/$username

#printf "\n[$scriptname] Generate HTML example"
generate_html_example $user_recent $user_id $user_token

#printf "\n[$scriptname] Remove backslash from HTML example"
sed -i 's/\\//g' photos/$username/index.html

#printf "\n[$scriptname] Create photo archive"
create_archive $username $archivedate $folder2archive

#printf "\n[$scriptname] Delete downloaded photos"
delete_downloaded_photos $username
fi

#printf "\n[$scriptname] Send mail"
send_mail $logdate $scriptname $email

#printf "\n"
exit
