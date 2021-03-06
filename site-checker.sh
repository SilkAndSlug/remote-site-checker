#!/bin/bash
########
# Crawls the given URL, checking for wget errors (e.g. HTTP 404) and PHP errors 
# (e.g. FATAL)
########



################################################################################
## Bootstrap
################################################################################

set -u;	## unset vars throw errors
set -e;	## errors exit



################################################################################
## Config
################################################################################

source /home/silkandslug/bin/includes/definitions.sh;

## recursive, 2 prior lines, ignore Silk-Framework, images, etc
readonly GREP_PARAMS=(-B 2 --exclude-dir=vendors/ --exclude-dir=silk/ --exclude-dir=migrate/ --exclude-dir=export/ --exclude-dir=data/ --exclude-dir=images/ --exclude=*.jpg -r);



################################################################################
## Init vars
################################################################################


## debugging
export DEBUG_LEVEL="$DEBUG_DEFAULT";


## init path to config
export CONFIG_FILE='';


## website to check
export DOMAIN='';
export TARGET='';


## login to web-server (HTTP)
export HTTP_LOGIN=('');	## must be populated
export HTTP_PASSWORD='';
export HTTP_USERNAME='';

## login to site (web form)
export FORM='User/Login';
export PASSWORD='';
export USERNAME='';
export LOGIN='';
export EMAIL_ADDRESS='';


## are we crawling the site?
export DO_DOWNLOAD=true;
export EXCLUDE_DIRS='';


## are we checking the crawl?
export DO_CHECKING=true;


## output
export OUTPUT_DIR='/tmp/site-checker';
export LOG_FILE='';
export REPORT_FILE='';
export SITE_DIR='';


## @var	IS_CRONJOB	bool	Toggle for unsupervised checking, e.g. via Cron
export IS_CRONJOB=false;



################################################################################
## Functions
################################################################################


function echo_usage() {
	echo "Usage: $(basename "$0") [OPTIONS] [TARGET]";
	echo;
	echo "TARGET should be a URL, including protocol";
	echo;
	echo "-c|--configuration	Path to config file";
	echo "-cj|--cronjob		Caller is a cronjob; run script non-interactively";
	echo "-d|--dir		Directory to hold generated files; defaults to /tmp/site-checker";
	echo "-f|--form		URL for login form, relative to TARGET; defaults to User/Login";
	echo "-u|--user		username for login form";
	echo "--http-username		HTTP-login for TARGET";
	echo "--http-password		HTTP-login for TARGET";
	echo "-p|--password		Password for login form";
	echo "-X|--exclude-directories		Comma-separated(?) list of /directories/ to NOT crawl";
	echo "-nc|--no-checking		Don't refresh the report; output previous report";
	echo "-nd|--no-download		Don't refresh the download; check previous downloads";
	echo "-v increase verbosity (-v = info; -vv = verbose; -vvv = debug)";
	echo;
	echo "Returns 1 on error, and 0 on success";

	return 0;
}	## end function


function init() {
	if [ $# -eq 0 ]; then
		echo_usage;
		return 1;
	fi;


	## declare vars
	local \
		status \
	;



	########
	## get config
	########

	read_config_from_file "$@" || return 1;

	read_config_from_command_line "$@" || return 1;



	########
	## test config
	########


	## if TARGET missing or empty, exit
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "init::TARGET $TARGET";
	if [ -z "$TARGET" ]; then
		echoerr "No target given";
		echo_usage;
		return 1;
	fi;


	########


	extract_domain_from_target  || return 1;

	update_internal_vars_with_config  || return 1;

	init_dirs  || return 1;


	return 0;
}	## end function


function read_config_from_file() {
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Reading config from file...";


	## handle params
	while [ $# -gt 0 ]; do
		key="$1";

		case "$key" in
			-c|--configuration )
				CONFIG_FILE="$2";
				shift;	## past argument
				;;
		esac;
		shift; # past argument
	done;
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "CONFIG_FILE = $CONFIG_FILE";


	## if CONFIG_FILE missing or empty, return
	if [ -z "$CONFIG_FILE" ]; then
		[ "$DEBUG_LEVEL" -ge "$DEBUG_DEFAULT" ] && echo "No config file selected; skipping";
		return 0;
	fi;

	if [ ! -f "$CONFIG_FILE" ]; then
		echoerr "File $CONFIG_FILE doesn't exist; crashing";
		exit 1;
	fi;


	# shellcheck source=/home/silkandslug/site-checker/dev/demo.cfg
	source "$CONFIG_FILE";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...okay";


	return 0;
}	## end function


function read_config_from_command_line() {
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Reading config from command line...";


	## declare vars
	local \
		key \
	;


	## handle params
	while [ $# -gt 0 ]; do
		key="$1";

		case "$key" in
			-c|configuration )
				## config file; skip
				shift;	## past argument
				;;

			-cj|--cronjob )
				IS_CRONJOB=true;
				;;

			-d|--dir )
				OUTPUT_DIR="$2";
				shift;	## past argument
				;;

			-e|--email )
				EMAIL_ADDRESS="$2";
				shift;	## past argument
				;;

			-f|--form )
				FORM="$2";
				shift;	## past argument
				;;

			--help )
				echo_usage;
				exit 1;
				;;

			--http-password )
				HTTP_PASSWORD="$2";
				shift;	## past argument
				;;

			--http-username )
				HTTP_USERNAME="$2";
				shift;	## past argument
				;;

			-l|--login )
				LOGIN="$2";
				shift;	## past argument
				;;

			-p|--password )
				PASSWORD="$2";
				shift;	## past argument
				;;

			-nc|--no-check|--no-checking )
				DO_CHECKING=false;
				;;

			-nd|--no-download|--no-downloading )
				DO_DOWNLOAD=false;
				;;

			-u|--user )
				USERNAME="$2";
				shift;	## past argument
				;;

			-v|--verbose )
				## debugging++
				DEBUG_LEVEL=$((DEBUG_LEVEL+1));
				;;

			-X|--exclude-directories )
				EXCLUDE_DIRS="$2";
				shift;	## past argument
				;;

			* )
				TARGET="$key";
				;;
		esac;
		shift; # past argument
	done;
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "DEBUG_LEVEL = $DEBUG_LEVEL";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "FORM = $FORM";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "PASSWORD = $PASSWORD";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "USERNAME = $USERNAME";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "EMAIL_ADDRESS = $EMAIL_ADDRESS";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "LOGIN = $LOGIN";


	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...okay";
	return 0;
}	## end function


function extract_domain_from_target() {
	## check input
	if [ -z "$TARGET" ]; then
		echoerr "\$TARGET must be a valid string; quitting";
		return 1;
	fi;


	## extract DOMAIN from TARGET
	DOMAIN=$(echo "$TARGET" | awk -F/ '{print $3}');
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "DOMAIN = $DOMAIN";


	## check output
	if [ -z "$DOMAIN" ]; then
		echoerr "Failed to extract \$DOMAIN from \$TARGET ($TARGET); quitting";
		return 1;
	fi;


	return 0;
}	## end function



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
	HTTP_LOGIN=('');	## must be populated
	if [ -n "$HTTP_USERNAME" ] && [ -n "$HTTP_PASSWORD" ]; then
		HTTP_LOGIN=(--auth-no-challenge --http-user="$HTTP_USERNAME" --http-password="$HTTP_PASSWORD");
	fi;


	## cookie file must exit
	touch "$COOKIE_FILE" || {
		echoerr "Can't touch $COOKIE_FILE; crashing";
		exit 1;
	};


	return 0;
}	## end function



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
}	## end function



########
# Logs-in to website
#
# Globals
#	COOKIE_FILE		Where to store cookie
#	EMAIL_ADDRESS	Login credential
#	FORM			URL of login page, relative to $TARGET
#	HTTP_LOGIN		List of params for HTTP login
#	LOGIN			Login credential
#	PASSWORD		Login credential
#	SITE_DIR		Prefix for output files
#	TARGET			Site's root URL
#	USERNAME		Login credential
#
# Arguments
#	None
#
# Returns
#	None
########
function login_to_site() {
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "site-checker::login";


	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Logging-in...";


	## declare vars
	local \
		command \
		content \
		cookies \
		login_clause \
		tmp_log \
		verbosity \
	;


	## config

	## can't be quiet, as we're checking for redirects
	verbosity='';
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && verbosity="-vvv";

	cookies=(--keep-session-cookies --save-cookies "$COOKIE_FILE");

	content='';
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
		[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...not configured; skipping";
		return 0;
	fi;
	login_clause=("--post-data='$content'");

	tmp_log=$(tempfile);


	## build command
	command="wget \
		$verbosity \
		--output-file=$tmp_log \
		--directory-prefix $SITE_DIR \
		${HTTP_LOGIN[*]} \
		${cookies[*]} \
		${login_clause[*]} \
		$TARGET/$FORM";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "login::command $command";

	$command || {
		echoerr "Failed to login to $FORM with ${login_clause[*]}; quitting";
		return 1;
	};


	## did the form handle our login?
	## grep returns 0 if found
	grep 'Location:' "$tmp_log" >/dev/null && {
		echoerr "Failed to redirect after login to $FORM with ${login_clause[*]} [bad credentials?]; quitting";
		return 1;
	};


	## did the form accept our login?
	## grep returns 0 if found
	( grep 'Location:' "$tmp_log" | grep "$FORM" ) >/dev/null && {
		echoerr "$FORM redirected to $FORM with ${LOGIN[*]} [bad credentials?]; quitting";
		return 1;
	};


	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...okay";
	return 0;
}	## end function



########
# Download the named site to a local dir
#
# Globals
#	COOKIE_FILE		Where the site login is stored
#	DOMAIN			Domain we're downloading; used to disable throttling
#	EXCLUDE_DIRS	Dirs to NOT download
#	HTTP_LOGIN		Params for HTTP login; passed to wget
#	LOG_FILE		Where to store output
#	SITE_DIR		Where to store files
#	TARGET			URL to download
#
# Arguments
#	None
#
# Returns
#	None
########
function download_site() {
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Downloading site...";


	## empty cache
	if [ -d "$SITE_DIR" ]; then rm -rf "$SITE_DIR"; fi;
	if [ -d "$SITE_DIR" ]; then
		echoerr "Dir $SITE_DIR still exists; quitting";
		return 1;
	fi;


	## declare vars
	local \
		command \
		cookies \
		delay \
		exclude_clause \
		log \
		mirror \
		status \
		tmp \
	;


	## config
	log=("--output-file $LOG_FILE");
	mirror=(--mirror "-e robots=off" --page-requisites --no-parent);

	cookies=('--keep-session-cookies' "--load-cookies $COOKIE_FILE");

	exclude_clause=('');	## must be populated
	if [ ! -z "$EXCLUDE_DIRS" ]; then
		exclude_clause=(--exclude-directories="$EXCLUDE_DIRS");
	fi;

	## wait 1sec, unless we're hitting the DEV server
	delay='--wait 1';
	if [ 'dev.silkandslug.com' = "${DOMAIN,,}" ]; then
		delay='';
	fi;


	## assemble command
	## --no-directories is a workaround for wget's 'pathconf: not a directory' error/bug
	command="wget \
		--directory-prefix $(dirname "$SITE_DIR") \
		--adjust-extension \
		--content-on-error \
		--convert-links \
		--page-requisites \
		${cookies[*]} \
		$delay \
		${exclude_clause[*]} \
		${log[*]} \
		${mirror[*]} \
		${HTTP_LOGIN[*]} \
		$TARGET \
	";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo -e "download_site::command $command";


	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...starting crawl (this will take a while)...";


	SECONDS=0;	## built-in var
	$command;
	status="$?";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "download_site::status $status";


	## 8 := server error (e.g. 404) - which we ignore (for now!)
	if [ 0 -ne "$status" ] && [ 8 -ne "$status" ]; then
		tmp=$(seconds2time "$SECONDS");
		echo "wget exited with code $status after $tmp" >> "$LOG_FILE";
		echoerr "Failed to download site after $tmp. See $LOG_FILE (or call $(basename "$0") -nd) for details";
		return 1;
	fi;


	tmp=$(seconds2time "$SECONDS");
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...done in $tmp";


	return 0;
}	## end function


function fettle_log_file() {
	cp "$LOG_FILE" "$LOG_FILE.bak";

	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Fettling log file...";

	## strip lines
	sed -i "s|Reusing existing connection to [^:]*:80\.||" "$LOG_FILE";

	## strip times
	sed -i "s|--[^h]*||" "$LOG_FILE";

	## strip text before error
	sed -i "s|HTTP request sent, awaiting response... ||" "$LOG_FILE";

	## strip empty lines
	sed -i 'n;d' "$LOG_FILE";

	## add empty line after error
	sed -i '/^[0-9]/G' "$LOG_FILE";


	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...done";

	return 0;
}	## end function


function check_for_HTTP_errors() {
	## output
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "site-checker::check_for_HTTP_errors";
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Checking for HTTP errors...";


	## declare
	local \
		status \
	;


	## test for error
	if [ "$LOG_FILE" == "$REPORT_FILE" ]; then
		echoerr "LOG_FILE is the same as REPORT_FILE; skipping";
		return 1;
	fi;


	## output [45]xx errors to tmp file
	grep -B 2 'awaiting response... [45]' "$LOG_FILE" >> "$REPORT_FILE" 2>&1;
	status=$?;


	## grep exits 0 if found
	if [ 0 -eq "$status" ]; then
		echoerr "Found 45x errors; quitting";
		return 2; 
	fi;


	## grep exits 1 if not found
	if [ 1 -ne "$status" ]; then
		echoerr "Couldn't check for HTTP errors; quitting";
		return 1; 
	fi;


	## output
	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...okay";


	## tidy & quit
	return 0;
}	## end function


function check_for_PHP_errors() {
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "site-checker::check_for_PHP_errors";

	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Checking for PHP errors..."


	## declare vars
	local \
		is_okay \
	;


	## init vars
	is_okay=true;


	## grep returns 1 if nothing found
	grep "${GREP_PARAMS[@]}" 'Fatal error: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Error:</b>' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Warning: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Notice: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;

	grep "${GREP_PARAMS[@]}" 'Strict Standards: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;


	if ! "$is_okay" ; then
		echoerr "Found PHP errors; quitting";
		return 2;
	fi;


	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...okay";

	return 0;
}	## end function


function check_for_PHPTAL_errors() {
	[ "$DEBUG_LEVEL" -ge "$DEBUG_DEBUG" ] && echo "site-checker::check_for_PHPTAL_errors";

	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "Checking for PHPTAL error-strings..."


	## declare vars
	local \
		is_okay \
	;


	## init vars
	is_okay=true;


	grep "${GREP_PARAMS[@]}" 'Error: ' "$SITE_DIR" >> "$REPORT_FILE" && is_okay=false;


	if ! "$is_okay" ; then
		echoerr "Found PHPTAL error-strings; quitting";
		return 2;
	fi;


	[ "$DEBUG_LEVEL" -ge "$DEBUG_INFO" ] && echo "...okay";

	return 0;
}	## end function


function seconds2time() {
	if [ $# -ne 1 ]; then
		echoerr "Usage: seconds2time {seconds}";
		return 1;
	fi;

	T=$1;
	D=$((T/60/60/24));
	H=$((T/60/60%24));
	M=$((T/60%60));
	S=$((T%60));


	if [ $D -eq 0 ]; then
		printf '%02d:%02d:%02d' $H $M $S;
		return 0;
	fi;
	printf '%d days %02d:%02d:%02d' $D $H $M $S;

	return 0;
}	## end function



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
	## declare vars
	local \
		ERROR_COUNT \
		is_okay \
		status \
	;


	## read config, etc
	init "$@" || return 1;


	## download the site
	if $DO_DOWNLOAD ; then
		login_to_site	|| return 1;
		download_site	|| return 1;
		fettle_log_file	|| return 1;
	fi;


	## check site
	is_okay=true;
	if $DO_CHECKING ; then
		[ -f "$REPORT_FILE" ] && rm "$REPORT_FILE"; # empty report

		check_for_HTTP_errors	|| is_okay=false;
		check_for_PHP_errors	|| is_okay=false;
		check_for_PHPTAL_errors	|| is_okay=false;
	fi;

	if ! $is_okay ; then
		ERROR_COUNT=$(( $(wc -l < "$REPORT_FILE") / 3 ));
		echoerr "Found $ERROR_COUNT errors";

		if ! $IS_CRONJOB ; then
			read -n1 -r -p "Press space to continue..." key ;
		fi;

		cat "$REPORT_FILE" || return 1;

		return 1;
	fi;


	## tidy login page, if any
	[ -f "$FORM" ] && rm "$FORM";


	return 0;
}	## end function



################################################################################
## Run, tidy, quit
################################################################################

main "$@" || exit 1;
exit 0;
