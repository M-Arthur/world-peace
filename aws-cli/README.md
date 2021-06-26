# AWS-CLI Helpers
[![aws-cli version](https://img.shields.io/badge/aws--cli-v1-blue.svg)](https://aws.amazon.com/cli/)

Here are scripts which make send requests to AWS from command line simpler.

---
### awsassumerole.sh
This script assumes AWS role and sets the relevant ENV variables for the users,
so users can request AWS resources as assumed role without adding `--profile` 
flag or manually update ENV variables.
#### Usage
1. Please modify the following parts of code based on your need. This is basically
   a `switch` clause. You can add/remove `cases` as you wishes.
   ```bash
   165| case $targetEnv in
   166| "sandbox")
   167|   accountId=<Account ID of the assume role>
   168|   ;;
   169| "uat")
   170|   accountId=<Account ID of the assume role>
   171|   ;;
   172| "production")
   173|   read -p "Are you sure to assume production role? " -r
   174|   echo    # move to a new line
   175|   if [[ $REPLY =~ ^(YES|yes|[Yy])$ ]]
   176|   then
   177|     accountId=<Account ID of the assume role>
   178|   fi
   179|   ;;
   180| *)
   181| esac
   ```
2. Add the following codes into file `.profile`, `.bashrc` or other files which load 
shell configs automatically.
    ```bash
    alias assumerole='source <Directory of your choice>/awsassumerole.sh'
    ```
3. Make sure you marked this file as executable (It can be done via cmd `chmod`)

Now you are ready to go.