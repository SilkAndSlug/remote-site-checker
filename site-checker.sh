#!/bin/bash

## Crawls the given URL, checking for wget errors (e.g. HTTP 404) and PHP 
## errors (e.g. FATAL)



#####
# config
#####

TMP_DIR="/tmp/site-checker";
COOKIES_DIR="$TMP_DIR/cookies";
LOGS_DIR="$TMP_DIR/logs";
REPORTS_DIR="$TMP_DIR/reports";
SITES_DIR="$TMP_DIR/sites";



#####
# init
#####

# unset vars throw errors
set -u;


# load definitions
source "/home/steve/silkandslug/tools/site-checker/dev/includes/definitions.sh";
# load functions
source "/home/steve/silkandslug/tools/site-checker/dev/functions/site-checker.sh";

main() {
	init "$@";
	if [ "$?" -gt 0 ]; then return "$?"; fi;


	if [ false == $REPORT_ONLY ]; then
		login ;
		if [ "$?" -gt 0 ]; then return "$?"; fi;


		download_site ;
		if [ "$?" -gt 0 ]; then return "$?"; fi;


		check_site_for_HTTP_errors ;
		if [ "$?" -gt 0 ]; then return "$?"; fi;


		check_site_for_PHP_errors ;
		if [ "$?" -gt 0 ]; then return "$?"; fi;
	fi;
	

	local ERROR_COUNT=$(( `cat $REPORT_FILE | wc -l` / 3 ));
	if [ 0 -lt $ERROR_COUNT ]; then
		echo "Found $ERROR_COUNT errors";

		if [ false == $IS_CRONJOB ]; then
			read -n1 -r -p "Press space to continue..." key ;
		fi;

		cat "$REPORT_FILE" ;
		if [ "$?" -gt 0 ]; then return "$?"; fi;
	fi;



	
	return 0;
}
main "$@";
if [ "$?" -gt 0 ]; then exit "$?"; fi;



#####
# tidy & quit
#####

exit 0;
