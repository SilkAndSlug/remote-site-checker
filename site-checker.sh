#!/bin/bash
########
# Crawls the given URL, checking for wget errors (e.g. HTTP 404) and PHP errors 
# (e.g. FATAL)
########



################################################################################
## Bootstrap
################################################################################

set -u;	# unset vars throw errors
set -e;	# errors exit



################################################################################
## Config
################################################################################

source /home/silkandslug/bin/includes/definitions.sh;

# recursive, 2 prior lines, ignore Silk-Framework, images, etc
readonly GREP_PARAMS=(-B 2 --exclude-dir=vendors/ --exclude-dir=silk/ --exclude-dir=migrate/ --exclude-dir=export/ --exclude-dir=data/ --exclude-dir=images/ --exclude=*.jpg -r);



################################################################################
## Init vars
################################################################################

#debugging
export DEBUG_LEVEL="$DEBUG_QUIET";

export CONFIG_FILE="";

# server
export DOMAIN="";
export TARGET="";

# login to server
export HTTP_LOGIN=("");	# must be populated
export HTTP_PASSWORD="";
export HTTP_USERNAME="";

# login to site
export FORM="User/Login";
export PASSWORD="";
export USERNAME="";
export LOGIN="";
export EMAIL_ADDRESS=""

# downloads
export DO_DOWNLOAD=true;
export EXCLUDE_DIRS="";

# output
export OUTPUT_DIR="/tmp/site-checker";
export LOG_FILE="";
export REPORT_FILE="";
export SITE_DIR="";

# post-processing
export IS_CRONJOB=false;
export DO_CHECKING=true;



################################################################################
## Functions
################################################################################


function init() {
	if [ $# -eq 0 ]; then
		echo_usage;
		return 1;
	fi;


	local status ;

	read_config_from_file "$@" || return 1;

	read_config_from_command_line "$@" || return 1;

	# if TARGET missing or empty, exit
	if [[ "" == "$TARGET" ]]; then
		echoerr "No target given";
		echo_usage;
		return 1;
	fi;

	extract_domain_from_target  || return 1;

	update_internal_vars_with_config  || return 1;

	init_dirs  || return 1;


	return 0;
}


function echo_usage() {
	echo "Usage: $(basename "$0") [OPTIONS] [TARGET]";
	echo "";
	echo "TARGET should be a URL, including protocol";
	echo "";
	echo "-c|--configuration	Path to config file";
	echo "-cj|--cronjob		Caller is a cronjob; run script non-interactively";
	echo "-d|--dir		Directory to hold generated files; defaults to /tmp/site-checker";
	echo "-f|--form		URL for login form, relative to TARGET; defaults to User/Login";
	echo "-u|--user		username for login form";
	echo "--http-username		HTTP-login for TARGET";
	echo "--http-password		HTTP-login for TARGET";
	echo "-p|--password		Password for login form";
	echo "-X|--exclude-directories		Comma-separated(?) list of /directories/ to NOT crawl";
	echo "-nc|--no-checking		Don't refresh the report; output previous report"
	echo "-nd|--no-download		Don't refresh the download; check previous downloads"
	echo "-v increase verbosity (-v = info; -vv = verbose; -vvv = debug)";
	echo "";
	echo "Returns 1 on error, and 0 on success";

	return 0;
}


function read_config_from_file() {
	echo "Reading config from file...";

	# handle params
	while [[ $# -gt 0 ]]; do
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
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "CONFIG_FILE = $CONFIG_FILE"; fi;


	# if CONFIG_FILE missing or empty, return
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
	while [[ $# -gt 0 ]]; do
		key="$1"

		case $key in
			-c|configuration )
				# config file; skip
				shift;	# past argument
				;;

			-cj|--cronjob )
				IS_CRONJOB=true;
				;;

			-d|--dir )
				OUTPUT_DIR="$2";
				shift;	# past argument
				;;

			-e|--email )
				EMAIL_ADDRESS="$2";
				shift;	# past argument
				;;

			-f|--form )
				FORM="$2";
				shift;	# past argument
				;;

			--help )
				echo_usage;
				exit 1;
				;;

			--http-password )
				HTTP_PASSWORD="$2";
				shift;	# past argument
				;;

			--http-username )
				HTTP_USERNAME="$2";
				shift;	# past argument
				;;

			-l|--login )
				LOGIN="$2";
				shift;	# past argument
				;;

			-p|--password )
				PASSWORD="$2";
				shift;	# past argument
				;;

			-nc|--no-checking )
				DO_CHECKING=false;
				;;

			-nd|--no-download )
				DO_DOWNLOAD=false;
				;;

			-u|--user )
				USERNAME="$2";
				shift;	# past argument
				;;

			-v|--verbose )
				# debugging++
				DEBUG_LEVEL=$((DEBUG_LEVEL+1));
				;;

			-X|--exclude-directories )
				EXCLUDE_DIRS="$2";
				shift;	# past argument
				;;

			* )
				TARGET=$key;
				;;
		esac
		shift # past argument
	done
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "DEBUG_LEVEL = $DEBUG_LEVEL"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "FORM = $FORM"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "PASSWORD = $PASSWORD"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "USERNAME = $USERNAME"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "EMAIL_ADDRESS = $EMAIL_ADDRESS"; fi;
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "LOGIN = $LOGIN"; fi;

	echo "...okay";
	return 0;
}


function extract_domain_from_target() {
	# extract DOMAIN from TARGET
	DOMAIN=$(echo "$TARGET" | awk -F/ '{print $3}');
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ]; then echo "DOMAIN = $DOMAIN"; fi;

	return 0;
}



########
# Derives global configs from other global configs
#
# Globals
#	Lots
#
# Arguments
#	None
#
# Returns
#	None
########
function update_internal_vars_with_config() {
	## absolute paths
	COOKIE_FILE="$OUTPUT_DIR/$DOMAIN.cookie";
	LOG_FILE="$OUTPUT_DIR/$DOMAIN.log";
	REPORT_FILE="$OUTPUT_DIR/$DOMAIN.report";
	SITE_DIR="$OUTPUT_DIR/$DOMAIN";


	## for wget
	if [[ -n "$HTTP_USERNAME" && -n "$HTTP_PASSWORD" ]]; then
		HTTP_LOGIN=(--auth-no-challenge --http-user="$HTTP_USERNAME" --http-password="$HTTP_PASSWORD");
	fi;


	return 0;
}



########
# Creates necessary dirs
#
# Globals
#	OUTPUT_DIR		Where to store reports
#	SITE_DIR		Where to store downloaded files
#
# Arguments
#	None
#
# Returns
#	None
########
function init_dirs() {
	mkdir -p "$OUTPUT_DIR" || {
		echoerr "Failed to find/mk $OUTPUT_DIR; crashing";
		exit 1;
	}


	mkdir -p "$SITE_DIR" || {
		echoerr "Failed to find/mk $SITE_DIR; crashing";
		exit 1;
	}


	return 0;
}


function login() {
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ]; then echo "site-checker::login"; fi;


	echo "Logging-in...";

	# can't be quiet, as we're checking for redirects
	local VERBOSITY="";
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ]; then VERBOSITY="-vvv"; fi;

	local COOKIES=(--keep-session-cookies --save-cookies "$COOKIE_FILE");

	local content="";
	if [ -n "$LOGIN" ]; then
		content="$content&$LOGIN";
	fi;
	if [ -n "$EMAIL_ADDRESS" ]; then
		content="$content&email_address=$EMAIL_ADDRESS";
	fi;
	if [ -n "$PASSWORD" ]; then
		content="$content&password=$PASSWORD";
	fi;
	if [ -n "$USERNAME" ]; then
		content="$content&username=$USERNAME";
	fi;
	if [ -z "$content" ]; then
		echo "...not configured; skipping";
		return 0;
	fi;
	local login_clause=("--post-data='$content'");

	local tmp_log=$(tempfile);

	local command="wget \
		$VERBOSITY \
		--output-file=$tmp_log \
		--directory-prefix $SITE_DIR \
		${HTTP_LOGIN[*]} \
		${COOKIES[*]} \
		${login_clause[*]} \
		$TARGET/$FORM";
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_VERBOSE" ]; then echo "login::command: $command"; fi;

	$command || {
		echoerr "Failed to login to $FORM with ${login_clause[*]}; quitting";
		return 1;
	};


	# did the form handle our login?
	# grep returns 0 if found
	grep 'Location:' "$tmp_log" >/dev/null && {
		echoerr "Failed to redirect after login to $FORM with ${login_clause[*]} [bad credentials?]; quitting";
		return 1;
	};


	# did the form accept our login?
	# grep returns 0 if found
	( grep 'Location:' "$tmp_log" | grep "$FORM" ) >/dev/null && {
		echoerr "$FORM redirected to $FORM with ${LOGIN[*]} [bad credentials?]; quitting";
		return 1;
	};


	echo "...okay";
	return 0;
}
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ]; then echo "site-checker::download_site"; fi;


	echo "Downloading site (this will take a while)..."

function download_site() {
	if [ ${#SITE_DIR} -gt 4 ]; then
		rm -rf "$SITE_DIR";
	fi;

	local COOKIES=(--keep-session-cookies "--load-cookies $COOKIE_FILE");
	local LOG=("--output-file $LOG_FILE");
	local MIRROR=(--mirror "-e robots=off" --page-requisites --no-parent);

	local exclude_clause=("");	# must be populated
	if [ -n "$EXCLUDE_DIRS" ]; then
		local exclude_clause=(--exclude-directories="$EXCLUDE_DIRS");
	fi;


	# wait 1sec, unless we're hitting the DEV server
	local WAIT="--wait 1";
	if [ 'dev.silkandslug.com' == "${DOMAIN,,}" ]; then
		WAIT="";
	fi;


	# --no-directories is a workaround for wget's 'pathconf: not a directory' error/bug
	local command="wget \
		--adjust-extension --convert-links \
		--page-requisites --content-on-error \
		${exclude_clause[*]} \
		${HTTP_LOGIN[*]} \
		${COOKIES[*]} \
		${LOG[*]} \
		${MIRROR[*]} \
		$WAIT \
		--directory-prefix $SITE_DIR \
		$TARGET";
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_VERBOSE" ]; then echo "download_site: $command"; fi;


	SECONDS=0;	# built-in var
	$command;
	local status="$?";
	# 8 => server error (e.g. 404) - which we ignore (for now!)
	if [ 0 -ne "$status" ] && [ 8 -ne "$status" ]; then
		tmp=$(seconds2time "$SECONDS");
		echo "wget exited with code $status after $tmp" >> "$LOG_FILE";
		echoerr "Failed to download site after $tmp. See $LOG_FILE (or call $(basename "$0") -nd) for details";
		return 1;
	fi;


	tmp=$(seconds2time "$SECONDS");
	echo "...okay in $tmp";
	return 0;
}


function fettle_log_file() {
	cp "$LOG_FILE" "$LOG_FILE.bak";

	echo "Fettling log file...";

	# strip lines
	sed -i "s|Reusing existing connection to [^:]*:80\.||" "$LOG_FILE";

	# strip times
	sed -i "s|--[^h]*||" "$LOG_FILE";

	# strip text before error
	sed -i "s|HTTP request sent, awaiting response... ||" "$LOG_FILE";

	# strip empty lines
	sed -i 'n;d' "$LOG_FILE";

	# add empty line after error
	sed -i '/^[0-9]/G' "$LOG_FILE";


	echo "...done";

	return 0;
}


function check_for_HTTP_errors() {
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ]; then echo "site-checker::check_for_HTTP_errors"; fi;


	echo "Checking for HTTP errors...";


	# output [45]xx errors to tmp file
	grep -B 2 'awaiting response... [45]' "$LOG_FILE" >> "$REPORT_FILE" 2>&1;
	local status=$?;

	# grep exits 0 if found
	if [ "$status" -eq 0 ]; then 
		echoerr "Found 45x errors; quitting";
		return 2; 
	fi;

	# grep exits 1 if not found
	if [ "$status" -ne 1 ]; then 
		echoerr "Couldn't check for HTTP errors; quitting";
		return 1; 
	fi;


	echo "...okay";

	return 0;
}


function check_for_PHP_errors() {
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ]; then echo "site-checker::check_for_PHP_errors"; fi;

	echo "Checking for PHP errors..."

	local is_okay=true;

	# grep returns 1 if nothing found
	grep "${GREP_PARAMS[@]}" 'Fatal error: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Error:</b>' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Warning: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Notice: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Strict Standards: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;


	if [ false == "$is_okay" ]; then
		echoerr "Found PHP errors; quitting";
		return 2;
	fi;


	echo "...okay";

	return 0;
}


function check_for_PHPTAL_errors() {
	if [ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ]; then echo "site-checker::check_for_PHPTAL_errors"; fi;

	echo "Checking for PHPTAL error-strings..."

	local is_okay=true;

	grep "${GREP_PARAMS[@]}" 'Error: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;


	if [ false == "$is_okay" ]; then
		echoerr "Found PHPTAL error-strings; quitting";
		return 2;
	fi;


	echo "...okay";

	return 0;
}


function seconds2time() {
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



########
# Read inputs and trigger login, download, and/or reporting as appropriate
#
# Globals
#	DO_CHECKING		Bool
#	DO_DOWNLOAD		Bool
#	FORM			Login form; deleted at end
#	IS_CRONJOB		Bool
#	REPORT_FILE		Where to put outputs
#	TARGET			Used for feedback
#
# Arguments
#	@				Passed to init()
#
# Returns
#	None
########
function main() {
	init "$@" || return 1;


	echo "";
	echo "";
	echo "########";
	echo "## Running Site-Checker on $TARGET";
	echo "########";
	echo "";


	if [ true == $DO_DOWNLOAD ]; then
		echo '';
		echo '###';
		echo '# Starting download...';
		echo '###';
		echo '';

		login  || return 1;

		download_site  || return 1;

		fettle_log_file
		if [ 0 -ne "$?" ]; then return 1; fi;

		echo '';
		echo '###';
		echo '# ...done';
		echo '###';
		echo '';
	fi;


	local is_okay=true;
	local status;
	if [ true == "$DO_CHECKING" ]; then
		echo '';
		echo '###';
		echo '# Starting checking...';
		echo '###';
		echo '';

		[ -f "$REPORT_FILE" ] && rm "$REPORT_FILE"; # empty report

		check_for_HTTP_errors || is_okay=false;
		check_for_PHP_errors || is_okay=false;
		check_for_PHPTAL_errors || is_okay=false;
		echo '';
		echo '###';
		echo '# ...done';
		echo '###';
		echo '';
	fi;

	if [ false == "$is_okay" ]; then
		local ERROR_COUNT=$(( $(wc -l < "$REPORT_FILE") / 3 ));
		echoerr "Found $ERROR_COUNT errors";

		if [ false == $IS_CRONJOB ]; then
			read -n1 -r -p "Press space to continue..." key ;
		fi;

		cat "$REPORT_FILE" || return 1;

		return 1;
	fi;


	# tidy login page, if any
	[ -f "$FORM" ] && rm "$FORM";


	return 0;
}



################################################################################
## Run, tidy, quit
################################################################################

main "$@" || exit 1;
exit 0;
