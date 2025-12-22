#!/bin/bash

# Performs the full update process by running Dependabot CLI and then creating/updating PRs.

# Example usage:
# ./update.sh jobs/maven.gitlab.com.yml gitlab.com "" javiertuya javiertuya/dashgit-test / main java 0

if [ -f "dependabot" ]; then # Dependabot command a local downloaded file in CI
  DEPENDABOT_CMD=./dependabot
else # But a global command that must be installed using go (in windows)
  DEPENDABOT_CMD=dependabot
fi
echo "Dependabot CLI command: $DEPENDABOT_CMD"
# Clean temporary work files from previous executions
rm -f update-result.json
rm -f update-job.yml

# The job configuration file must be preprocessed because dependabot CLI does not replaces
# environment variables, except the credentials.password
# Multiple directories are allowed if separated with comma and without blank spaces
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

# Dependabot will set the result in a json that will be used to create the MRs
$DEPENDABOT_CMD update -f update-job.yml --timeout 20m > update-result.json
#cat update-result.json
#exit

# Two additional parameters (label and assignee)
./create.sh update-result.json $2$3 $5 $7 $8 $9