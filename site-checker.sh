#!/bin/bash

## Crawls the given URL, checking for wget errors (e.g. HTTP 404) and PHP
## errors (e.g. FATAL)



#####
# init
#####

# unset vars throw errors
set -u;



#####
# config
#####

TMP_DIR="/tmp/site-checker";
COOKIES_DIR="$TMP_DIR/cookies";
LOGS_DIR="$TMP_DIR/logs";
REPORTS_DIR="$TMP_DIR/reports";
SITES_DIR="$TMP_DIR/sites";



#####
# constants
#####

# debug levels
QUIET=0;
INFO=1;
VERBOSE=2;
DEBUG=3;



#####
# internal vars
#####

DEBUG_LEVEL=$QUIET;

COOKIE_FILE="";
CONFIG_FILE="";
DOMAIN="";
EXCLUDE_DIRS="";
FORM="User/Login";
HTTP_PASSWORD="";
HTTP_USERNAME="";
HTTP_LOGIN="";
LOG_FILE="";
PASSWORD="";
IS_CRONJOB=false;
REPORT_FILE="";
REPORT_ONLY=false;
SITE_DIR="";
TARGET="";
USERNAME="";



#####
# functions
#####

function echo_usage() {
	echo "$0 [OPTIONS] TARGET";
	echo "";
	echo "TARGET should be a URL, including protocol";
	echo "";
	echo "-c|--configuration	Path to config file";
	echo "-cj|--cronjob		Caller is a cronjob; run script non-interactively";
	echo "-f|--form		URL for login form, relative to TARGET; defaults to User/Login";
	echo "-u|--user		username for login form";
	echo "--http-username		HTTP-login for TARGET";
	echo "--http-password		HTTP-login for TARGET";
	echo "-p|--password		Password for login form";
	echo "-X|--exclude-directories		Comma-separated(?) list of /directories/ to NOT crawl";
	echo "-ro|--report-only		Don't crawl site; report on previous crawls"
	echo "-v increase verbosity (-v = info; -vv = verbose; -vvv = debug)";
	echo "";
	echo "Returns 1 on error, and 0 on success";

	return 0;
}


function init() {
	local status ;

	read_config_from_file "$@";
	if [ "$?" -ne 0 ]; then return $?; fi;

	read_config_from_command_line "$@";
	if [ "$?" -ne 0 ]; then return $?; fi;

	read_target_from_command_line "$@";
	if [ "$?" -ne 0 ]; then return $?; fi;

	extract_domain_from_target ;
	if [ "$?" -ne 0 ]; then return $?; fi;

	update_internal_vars_with_config ;
	if [ "$?" -ne 0 ]; then return $?; fi;

	init_dirs ;
	if [ "$?" -ne 0 ]; then return $?; fi;


	return 0;
}


function read_config_from_file() {

	echo "Reading config from file...";

	# handle params
	while [[ $# > 1 ]]; do
		key="$1"

		case $key in
			-c|--configuration )
				# debugging++
				CONFIG_FILE="$2";
				shift;	# past argument
				;;
		esac
		shift # past argument
	done
	if [ "$DEBUG_LEVEL" -ge "$DEBUG" ]; then echo "CONFIG_FILE = $CONFIG_FILE"; fi;


	# if TARGET missing or empty, return
	if [[ "" = "$CONFIG_FILE" ]]; then
		echo "No config file selected; skipping";
		return 0;
	fi;

	if [[ ! -f "$CONFIG_FILE" ]]; then
		echoerr "File $CONFIG_FILE doesn't exist";
		return 1;
	fi;


	source "$CONFIG_FILE";
	echo "...okay";


	return 0;
}


function read_config_from_command_line() {

	echo "Reading config from command line...";


	# handle params
	while [[ $# > 1 ]]; do
		key="$1"

		case $key in
			-cj|--cronjob )
				IS_CRONJOB=true;
				;;

			-f|--form )
				FORM="$2";
				shift;	# past argument
				;;

			--http-password )
				HTTP_PASSWORD="$2";
				shift;	# past argument
				;;

			--http-username )
				HTTP_USERNAME="$2";
				shift;	# past argument
				;;

			-p|--password )
				PASSWORD="$2";
				shift;	# past argument
				;;

			-ro|--report-only )
				REPORT_ONLY=true;
				;;

			-u|--user )
				USERNAME="$2";
				shift;	# past argument
				;;

			-v|--verbose )
				# debugging++
				DEBUG_LEVEL=$(($DEBUG_LEVEL+1));
				;;

			-X|--exclude-directories )
				EXCLUDE_DIRS="$2";
				shift;	# past argument
				;;
		esac
		shift # past argument
	done
	if [ "$DEBUG_LEVEL" -ge "$DEBUG" ]; then echo "DEBUG_LEVEL = $DEBUG_LEVEL"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG" ]; then echo "FORM = $FORM"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG" ]; then echo "PASSWORD = $PASSWORD"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG" ]; then echo "USERNAME = $USERNAME"; fi;


	echo "...okay";
	return 0;
}


function read_target_from_command_line() {

	TARGET=${!#};
	if [ "$DEBUG_LEVEL" -ge "$DEBUG" ]; then echo "TARGET = $TARGET"; fi;


	# if TARGET missing or empty, exit
	if [[ "" = "$TARGET" ]]; then
		echoerr "No target given";
		echo_usage;
		return 1;
	fi;


	return 0;
}


function extract_domain_from_target() {
	# extract DOMAIN from TARGET
	DOMAIN=`echo $TARGET | awk -F/ '{print $3}'`;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG" ]; then echo "DOMAIN = $DOMAIN"; fi;

	return 0;
}


function update_internal_vars_with_config() {
	COOKIE_FILE="$COOKIES_DIR/$DOMAIN.txt";
	LOG_FILE="$LOGS_DIR/$DOMAIN.log";
	REPORT_FILE="$REPORTS_DIR/$DOMAIN.txt";
	SITE_DIR="$SITES_DIR/$DOMAIN";

	if [[ ! -z "$HTTP_USERNAME" && ! -z "$HTTP_PASSWORD" ]]; then
		HTTP_LOGIN="--auth-no-challenge --http-user=$HTTP_USERNAME --http-password=$HTTP_PASSWORD";
	fi;

	return 0;
}


function init_dirs() {
	mkdir -p $SITE_DIR ;

	mkdir -p $COOKIES_DIR ;
	mkdir -p $LOGS_DIR ;
	mkdir -p $REPORTS_DIR ;

	return 0;
}


function login() {
	if [ $DEBUG_LEVEL -ge "$INFO" ]; then echo "site-checker::login"; fi;


	echo "Logging-in...";


	local VERBOSITY="-q";
	if [ $DEBUG_LEVEL -ge "$INFO" ]; then VERBOSITY="-vvv"; fi;

	local COOKIES="--keep-session-cookies --save-cookies $COOKIE_FILE";

	local LOGIN="--post-data username=$USERNAME&password=$PASSWORD --delete-after";

	local COMMAND="wget $VERBOSITY $HTTP_LOGIN $COOKIES $LOGIN $TARGET/$FORM";
	if [ $DEBUG_LEVEL -ge "$DEBUG" ]; then echo "login: $COMMAND"; fi;

	$COMMAND;
	if [ "$?" -ne 0 ]; then 
		echoerr "Failed to login to $FORM as $USERNAME";
		return 1;
	fi;


	echo "...okay";
	return 0;
}


function download_site() {
	if [ $DEBUG_LEVEL -ge "$INFO" ]; then echo "site-checker::download_site"; fi;


	echo "Downloading site..."
	# empty report
	if [[ -f "$REPORT_FILE" ]]; then rm "$REPORT_FILE"; fi;


	local COOKIES="--keep-session-cookies --load-cookies $COOKIE_FILE";
	local LOG="--output-file $LOG_FILE";
	local MIRROR="--mirror -e robots=off --page-requisites --no-parent";

	local exclude_clause="";
	if [ ! -z $EXCLUDE_DIRS ]; then
		local exclude_clause="--exclude-directories=$EXCLUDE_DIRS";
	fi;


	# wait 1sec, unless we're hitting the DEV server
	local WAIT="--wait 1";
	if [ "dev.silkandslug.com" == $(echo $DOMAIN,,) ]; then
		WAIT="";
	fi;


	# -nd is a workaround for wget's 'pathconf: not a directory' error/bug
	local COMMAND="wget --no-directories $exclude_clause $HTTP_LOGIN $COOKIES $LOG $MIRROR $WAIT --directory-prefix $SITES_DIR $TARGET 1>/dev/null";
	if [ $DEBUG_LEVEL -ge "$DEBUG" ]; then echo "download_site: $COMMAND"; fi;


	SECONDS=0;	# built-in var
	$COMMAND;
	if [ "$?" -ne 0 ]; then
		tmp=$(seconds2time $SECONDS);
		echoerr "Failed to download site after $tmp";
		return 1;
	fi;


	tmp=$(seconds2time $SECONDS);
	echo "...okay in $tmp";
	return 0;
}


function fettle_log_file() {
	cp $LOG_FILE $LOG_FILE.bak;

	echo "Fettling log file...";

	# strip lines
	sed -i "s|Reusing existing connection to [^:]*:80\.||" $LOG_FILE ;

	# strip times
	sed -i "s|--[^h]*||" $LOG_FILE ;

	# strip text before error
	sed -i "s|HTTP request sent, awaiting response... ||" $LOG_FILE ;

	# strip empty lines
	sed -i 'n;d' $LOG_FILE ;

	# add empty line after error
	sed -i '/^[0-9]/G' $LOG_FILE ;


	echo "...done";

	return 0;
}


	# rename, delete
	mv $TMP_FILE $REPORT_FILE;
	if [[ -f "$TMP_FILE" ]]; then rm "$TMP_FILE"; fi;


	return 0;
}


function check_site_for_PHP_errors() {
	if [ $DEBUG_LEVEL -ge "$INFO" ]; then echo "site-checker::check_site_for_PHP_errors"; fi;


	grep -r '^Fatal error: ' "$SITE_DIR" >> "$REPORT_FILE";
	if [ "$?" -gt 0 ]; then return "$?"; fi;

	grep -r '^Warning: ' "$SITE_DIR" >> "$REPORT_FILE";
	if [ "$?" -gt 0 ]; then return "$?"; fi;

	grep -r '^Notice: ' "$SITE_DIR" >> "$REPORT_FILE";
	if [ "$?" -gt 0 ]; then return "$?"; fi;

	grep -r '^Strict Standards: ' "$SITE_DIR" >> "$REPORT_FILE";
	if [ "$?" -gt 0 ]; then return "$?"; fi;


	echo "No PHP errors found";

	return 0;
}


function check_for_PHPTAL_errors() {
	if [ $DEBUG_LEVEL -ge "$INFO" ]; then echo "site-checker::check_for_PHPTAL_errors"; fi;

	echo "Testing site for PHPTAL errors..."

	is_okay=true;

	grep $GREP_PARAMS 'Error: ' "$SITE_DIR" >> "$REPORT_FILE";
	if [ "$?" -ne 0 ]; then is_okay=false; fi;


	if [ false = "$is_okay" ]; then
		echoerr "Found PHPTAL errors; quitting";
		return 1;
	fi;


	echo "No PHPTAL errors found";

	return 0;
}


function seconds2time () {
	if [ $# -ne 1 ]; then
		echoerr "Usage: seconds2time {seconds}";
		return 1;
	fi;

	T=$1
	D=$((T/60/60/24))
	H=$((T/60/60%24))
	M=$((T/60%60))
	S=$((T%60))


	if [ $D -eq 0 ]; then
		printf '%02d:%02d:%02d' $H $M $S
		return 0;
	fi
	printf '%d days %02d:%02d:%02d' $D $H $M $S;

	return 0;
}


function main() {
	local status;
	local is_okay;


	init "$@";
	status=$?;
	if [ "$?" -ne 0 ]; then return "$?"; fi;


	is_okay=true;
	if [ false == $REPORT_ONLY ]; then
		login ;
		if [ "$?" -ne 0 ]; then return "$?"; fi;

		download_site ;
		if [ "$?" -ne 0 ]; then return "$?"; fi;

		fettle_log_file
		if [ "$?" -ne 0 ]; then return "$?"; fi;


		# empty report
		if [[ -f "$REPORT_FILE" ]]; then rm "$REPORT_FILE"; fi;

		check_for_HTTP_errors ;
		if [ "$?" -ne 0 ]; then is_okay=false; fi;

		check_for_PHP_errors ;
		if [ "$?" -ne 0 ]; then is_okay=false; fi;

		check_for_PHPTAL_errors ;
		if [ "$?" -ne 0 ]; then is_okay=false; fi;
	fi;


	if [ false = "$is_okay" ]; then
		local ERROR_COUNT=$(( `cat $REPORT_FILE | wc -l` / 3 ));
		echo "Found $ERROR_COUNT errors";

		if [ false == $IS_CRONJOB ]; then
			read -n1 -r -p "Press space to continue..." key ;
		fi;

		cat "$REPORT_FILE" ;
		if [ "$?" -ne 0 ]; then return "$?"; fi;

		return 1;
	fi;


	return 0;
}


#####
# run, tidy, quit
#####

# run
main "$@";
if [ "$?" -ne 0 ]; then exit "$?"; fi;

# tidy login page, if any
if [[ -f "$FORM" ]]; then rm "$FORM"; fi;

# exit
exit 0;
