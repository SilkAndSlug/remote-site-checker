#####
# definitions
#####

SED_FUNCTION_NAME="[a-zA-Z_]\+";
SED_VARIABLE_NAME="[a-zA-Z_\o7f-\off][a-zA-Z0-9_\o7f-\off>-]*";
SED_CONSTANT_PATTERN="[a-zA-Z0-9_:]\+";
SED_STRING_PATTERN="[\\\"']\+[a-zA-Z0-9_: ]\+[\\\"']\+";
SED_VARIABLE_PATTERN="\$$SED_VARIABLE_NAME";

PERL_FUNCTION_REGEX="[a-zA-Z0-9_]";
PERL_VARIABLE_REGEX="[][a-zA-Z0-9_:'\"]";
PERL_CONST_REGEX="[a-zA-Z0-9_:'\"]";


# silk_debug
QUIET=0;
INFO=1;
VERBOSE=2;
DEBUG=3;


# commands
GREP='/bin/grep';
