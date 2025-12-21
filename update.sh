#!/bin/bash

# Performs the full update process by running Dependabot CLI and then creating/updating PRs.

# Example usage:
# ./update.sh jobs/maven.gitlab.com.yml gitlab.com "" javiertuya javiertuya/dashgit-test / main

# Dependabot command is a global command if installed using go (in windows)
#DEPENDABOT_CMD=dependabot
# But a local downloaded file in CI
DEPENDABOT_CMD=./dependabot

# The job configuration file must be preprocessed because dependabot CLI does not replaces
# environment variables, except the credentials.password
sed -e "s|\$GH_HOST|$2|" \
    -e "s|\$GH_PATH|$3|" \
    -e "s|\$GH_USERNAME|$4|" \
    -e "s|\$GH_REPO|$5|" \
    -e "s|\$GH_DIRECTORY|$6|" \
    -e "s|\$GH_BRANCH|$7|" \
    $1 > update-job.yml

echo "*** Begin dependabot CLI update using this job description:"
cat update-job.yml
echo ""

$DEPENDABOT_CMD update -f update-job.yml --timeout 20m > update-result.json
./create.sh update-job.yml $2$3 $5