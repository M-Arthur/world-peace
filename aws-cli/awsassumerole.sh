#!/bin/bash
# Clean the environment variables
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
# Put all the initialisations into a function to make sure that
# reset function is always called before initialisation.
function aar_init() {
  aar_reset

  AAR_ENUM_COLOR_RESET="\033[0m"
  AAR_ENUM_COLOR_GREEN="\033[32m"
  AAR_ENUM_COLOR_YELLOW="\033[33m"
  AAR_ENUM_COLOR_CYAN="\033[36m"

  aar_printResult=false
  aar_defaultCacheFile="/tmp/aws-assume-role-$(whoami)"
  aar_inputFile=$aar_defaultCacheFile
}

# print error message in red color
function aar_printError() {
  local red="\033[31m"
  local reset="\033[0m"
  printf "${red}ERROR: %s${reset}\n" "$1"
}

# Dependency check
if ! jq --help &> /dev/null
then
  aar_printError "Please install command 'jq'"
  return 1 2>/dev/null || exit 1
fi

if ! aws sts help &> /dev/null
then
  aar_printError "Please install 'aws-cli'"
  return 1 2>/dev/null || exit 1
fi

# This function can only be called on exit/return
function aar_cleanup() {
  # Clean up variables
  aar_reset

  # Clean up function declaration
  unset aar_printExpirationTime
  unset aar_reset
  unset aar_init
  unset aar_convertStringToLowercase
  unset aar_print
  unset aar_printError
  unset aar_stripQuotations
  unset aar_getValueFromJSONFile
  unset aar_outputSecrets
  unset aar_readSecretsFromFile
  unset aar_convertStringToTimestamp
  unset aar_buildRoleARN
  unset aar_getAccountID
  unset aar_cleanup
}

# Run function aar_cleanup when script returns
trap aar_cleanup EXIT

function aar_reset() {
  unset aar_printResult
  unset aar_targetRole
  unset aar_outputFile
  unset aar_sessionDuration
  unset aar_tokenCode
  unset aar_sessionName
  unset aar_inputFile
  unset aar_accountId
  unset aar_targetRoleARN
  unset aar_cachedRole
  unset aar_cachedAccountId
  unset aar_cachedRoleARN
  unset aar_cachedRoleName
  unset aar_flagValue
  unset aar_flagOption
  unset aar_defaultCacheFile
  unset AAR_ENUM_COLOR_GREEN
  unset AAR_ENUM_COLOR_RESET
  unset AAR_ENUM_COLOR_YELLOW
  unset AAR_ENUM_COLOR_CYAN
}

function aar_convertStringToLowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

function aar_print() {
  local message=$1
  if [ -n "$2" ]; then
    printf "${2}%s${AAR_ENUM_COLOR_RESET}\n" "$message"
  else
    echo "$message"
  fi
}

function aar_stripQuotations() {
  echo "$1" | sed -e 's/^"//' -e 's/"$//'
}

function aar_getValueFromJSONFile() {
  local file=$1
  shift
  local keyString=""
  while [ $# -gt 0 ]
  do
    keyString+=$1
    shift
  done
  aar_stripQuotations "$(jq "$keyString" "$file")"
}

function aar_outputSecrets() {
  echo ""
  echo "Output:"
  printf "AWS_ACCESS_KEY_ID=${AAR_ENUM_COLOR_GREEN}%s${AAR_ENUM_COLOR_RESET}\n" "$AWS_ACCESS_KEY_ID"
  printf "AWS_SECRET_ACCESS_KEY=${AAR_ENUM_COLOR_GREEN}%s${AAR_ENUM_COLOR_RESET}\n" "$AWS_SECRET_ACCESS_KEY"
  printf "AWS_SESSION_TOKEN=${AAR_ENUM_COLOR_GREEN}%s${AAR_ENUM_COLOR_RESET}\n" "$AWS_SESSION_TOKEN"
}

function aar_printExpirationTime() {
  local file=$1
  local expirationTime
  expirationTime=$(aar_getValueFromJSONFile "$file" .Credentials .Expiration)
  expirationTime=$(date -d "$expirationTime")
  printf "Expired Time: ${AAR_ENUM_COLOR_YELLOW}%s${AAR_ENUM_COLOR_RESET}\n" "$expirationTime"
}

function aar_readSecretsFromFile() {
  local file=$1
  AWS_ACCESS_KEY_ID=$(aar_getValueFromJSONFile "$file" .Credentials .AccessKeyId)
  AWS_SECRET_ACCESS_KEY=$(aar_getValueFromJSONFile "$file" .Credentials .SecretAccessKey)
  AWS_SESSION_TOKEN=$(aar_getValueFromJSONFile "$file" .Credentials .SessionToken)
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
  export AWS_SESSION_TOKEN
}

function aar_convertStringToTimestamp() {
  local timeString=$1
  if [ -z "$timeString" ]
  then
    date +%s
  else
    date -d "$timeString" +%s
  fi
}

function aar_buildRoleARN() {
  local accountId=$1
  local role=$2
  echo "arn:aws:iam::$accountId:role/$role"
}

function aar_getAccountID() {
  local targetEnv
  local accountId=""
  targetEnv=$(aar_convertStringToLowercase "$1")
  case $targetEnv in
    "sandbox")
      accountId=123456
      ;;
    "nonprod")
      accountId=123456
      ;;
    "production")
      read -p "Are you sure to assume production role? " -r
      echo    # move to a new line
      if [[ $REPLY =~ ^(YES|yes|[Yy])$ ]]
      then
        accountId=123456
      fi
      ;;
    *)
  esac
  echo $accountId
}

# Init all the necessary variables
aar_init

# Process input options
while [ $# -gt 0 ]
do
  aar_flagOption=$1
  shift
  if [[ $1 =~ ^- ]]
  then
    aar_flagValue=""
  else
    aar_flagValue=$1
    shift
  fi
  case $aar_flagOption in
    -h|--help)
      echo "awsassumerole - attempt to assume given AWS role"
      echo "                'source' command must be used if user wants the assume role automatically effect"
      echo "                example: source scripts/initiate_aws_assumed_role_credentials.sh -r <assumed-role> -n <unique-session-name> --token <token>"
      echo " "
      echo "awsassumerole -a/--accountId <account number> [options...]"
      echo "-h, --help                                    show brief help"
      echo "-i, --input-file <filepath>                   load session configured in the file and"
      echo "                                              refresh when session duration is less than 10 minutes"
      echo "-d, --duration <seconds>                      duration of the assume role session, default is 1 hour"
      echo "-n, --session-name <name>                     unique name for current assume role session"
      echo "-o, --output-file <filepath>                  put output of assume role command into the specified file"
      echo "-p, --onscreen-print                          print results of assume role command to screen"
      echo "-a, --accountId                               accountId of the assumed role"
      echo "-t, --token <token>                           token must be provided when MFA serial number is set."
      echo "                                              To set MFA serial number, user has to either pass the"
      echo "                                              environment variable MFA_SERIAL_NUMBER to the script"
      echo "                                              or export that variable so the script can pick it up"
      return 1 2>/dev/null || exit 1
      ;;
    -a|--accountId)
      aar_targetRole=$aar_flagValue
      if [[ ! $aar_targetRole =~ ^[0-9]+$ ]]
      then
        aar_printError "Option -a or --accountId must be provided with valid number."
        return 1 2>/dev/null || exit 1
      fi
      ;;
    -o|--output-file)
      aar_outputFile=$aar_flagValue
      if [[ $aar_outputFile =~ ^([a-zA-Z0-9_/.]+)/[a-zA-Z0-9_.]+$ ]]
      then
        if [[ ! -d ${BASH_REMATCH[1]} ]]
        then
          aar_printError "Directory '${BASH_REMATCH[1]}' does not exist."
          return 1 2>/dev/null || exit 1
        fi
      else
        aar_printError "String '$aar_outputFile' is not a valid filename."
        return 1 2>/dev/null || exit 1
      fi
      ;;
    -i|--input-file)
      aar_inputFile=$aar_flagValue
      ;;
    -p|--onscreen-print)
      aar_printResult=true
      ;;
    -d|--duration)
      aar_sessionDuration=$aar_flagValue
      ;;
    -t|--token)
      aar_tokenCode=$aar_flagValue
      ;;
    -n|--session-name)
      aar_sessionName=$aar_flagValue
      ;;
    *)
      # Break the while loop
      shift
      ;;
  esac
done

if [[ ! $aar_sessionDuration =~ ^[0-9]+$ ]] || [ "$aar_sessionDuration" -lt 1 ]
then
  aar_sessionDuration=3600
fi

aar_accountId=$(aar_getAccountID "$aar_targetRole")
if [ -z "$aar_accountId" ]
then
  aar_printError "Failed to get correct account ID based on role '$aar_targetRole'."
  return 1 2>/dev/null || exit 1
fi
aar_targetRoleARN=$(aar_buildRoleARN "$aar_accountId" "Developer")
printf "Assumed Role: ${AAR_ENUM_COLOR_YELLOW}%s${AAR_ENUM_COLOR_RESET}" "$aar_targetRoleARN"
printf " ${AAR_ENUM_COLOR_CYAN}(%s)${AAR_ENUM_COLOR_RESET}\n" "$aar_targetRole"

if [ -f "$aar_inputFile" ]; then
  aar_cachedRole=$(aar_getValueFromJSONFile "$aar_inputFile" .AssumedRoleUser .Arn)
  # Check whether data is in valid format
  if [[ $aar_cachedRole =~ ^arn:aws:sts::([0-9]+):assumed-role/([a-zA-Z]+)/(.*)$ ]]
  then
    aar_cachedAccountId=${BASH_REMATCH[1]}
    aar_cachedRoleName=${BASH_REMATCH[2]}
    aar_cachedRoleARN=$(aar_buildRoleARN "$aar_cachedAccountId" "$aar_cachedRoleName")
    if [ "$aar_cachedRoleARN" = "$aar_targetRoleARN" ]
    then
      # Check whether cached session duration is larger than 10 minutes
      if [ 600 -lt $(("$(aar_convertStringToTimestamp "$(aar_getValueFromJSONFile "$aar_inputFile" .Credentials .Expiration)")" - $(aar_convertStringToTimestamp ""))) ]
      then
        aar_readSecretsFromFile "$aar_inputFile"
        printf "Session Name: ${AAR_ENUM_COLOR_YELLOW}%s${AAR_ENUM_COLOR_RESET}\n" "${BASH_REMATCH[3]}"
        aar_printExpirationTime "$aar_inputFile"
        if $aar_printResult
        then
          aar_outputSecrets
        fi
        return 1 2>/dev/null || exit 1
      else
        if [ -z "$aar_targetRoleARN" ]
        then
          aar_targetRoleARN=$aar_cachedRoleARN
        fi
        if [ -z "$aar_sessionName" ]
        then
          aar_sessionName=${BASH_REMATCH[3]}
        fi
        if [ -z "$aar_outputFile" ]
        then
          aar_outputFile=$aar_inputFile
        fi
      fi
    else
      aar_printError "Required role and role in given file are different."
      return 1 2>/dev/null || exit 1
    fi
  else
    aar_printError "Failed to load Role ARN from given file '$aar_inputFile'."
    return 1 2>/dev/null || exit 1
  fi
fi

if [ -z "$aar_outputFile" ]
then
  if [ -f "$aar_inputFile" ]
  then
    aar_outputFile=$aar_inputFile
  else
    aar_outputFile=$aar_defaultCacheFile
  fi
fi

if [ -z "$aar_sessionName" ]
then
  aar_sessionName="${aar_targetRole}-$(whoami)-$$"
elif [[ ! $aar_sessionName =~ ^[a-z0-9]+[a-z0-9-]+[a-z0-9]$ ]]
then
  aar_printError "Session name '$aar_sessionName' is invalid."
  return 1 2>/dev/null || exit 1
fi
printf "Session Name: ${AAR_ENUM_COLOR_YELLOW}%s${AAR_ENUM_COLOR_RESET}\n" "$aar_sessionName"

if [ -z "$aar_targetRoleARN" ]
then
  aar_printError "Option -r or --role is missing."
  return 1 2>/dev/null || exit 1
fi

if [ -n "$MFA_SERIAL_NUMBER" ]
then
  if [[ $MFA_SERIAL_NUMBER =~ ^arn:aws:iam::[0-9]+:mfa/[a-zA-Z0-9.-_@]+$ ]]
  then
    while [ -z "$aar_tokenCode" ] || [[ ! $aar_tokenCode =~ ^[0-9]+$ ]]
    do
      read -p "Please enter MFA token: " -r
      if [[ $REPLY =~ ^[0-9]{6}$ ]]
      then
        aar_tokenCode=$REPLY
      else
        aar_printError "MFA Code must be 6 digit number."
        echo ""
      fi
    done
  else
    aar_printError "MFA serial number '$MFA_SERIAL_NUMBER' is invalid."
    return 1 2>/dev/null || exit 1
  fi
fi

# Build command
aar_cmd="aws sts assume-role --role-arn ${aar_targetRoleARN} --role-session-name ${aar_sessionName} --duration-seconds ${aar_sessionDuration}"
if [ -n "$MFA_SERIAL_NUMBER" ]
then
  aar_cmd+=" --serial-number ${MFA_SERIAL_NUMBER} --token-code ${aar_tokenCode}"
fi

echo "Command about to be execute:"
echo "$aar_cmd"
$aar_cmd >"$aar_outputFile"
aar_printExpirationTime "$aar_outputFile"
aar_readSecretsFromFile "$aar_outputFile"
if $aar_printResult
then
  aar_outputSecrets
fi
