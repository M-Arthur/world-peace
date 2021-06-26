# AWS-CLI Helpers
[![aws-cli version](https://img.shields.io/badge/aws--cli-v1-blue.svg)](https://aws.amazon.com/cli/)

Here are scripts which make send requests to AWS from command line simpler.

---
### awsassumerole.sh
This script assumes AWS role and sets the relevant ENV variables for the users,
so users can request AWS resources as assumed role without adding `--profile` 
flag or manually update ENV variables.
#### Usage
1. Add the following codes into file `.profile`, `.bashrc` or other files which load 
shell configs automatically.
    ```bash
    alias assumerole='source <Directory of your choice>/awsassumerole.sh'
    ```
3. Make sure you marked this file as executable (It can be done via cmd `chmod`)

Run command with option `-h` or `--help` for more details.