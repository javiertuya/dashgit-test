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
sed -e "s|\$GL_HOST|$2|" \
    -e "s|\$GL_PATH|$3|" \
    -e "s|\$GL_USERNAME|$4|" \
    -e "s|\$GL_REPO|$5|" \
    -e "s|\$GL_DIRECTORY|$6|" \
    -e "s|\$GL_BRANCH|$7|" \
    $1 > update-job.yml

# Get language label from package manager name
GL_MANAGER=$(grep "package-manager:" update-job.yml | sed 's/.*: //' | xargs)
echo "using package manager: $GL_MANAGER"
if [ "$GL_MANAGER" = "maven" ]; then GL_LANG="java"
elif [ "$GL_MANAGER" = "npm_and_yarn" ]; then GL_LANG="javascript"
elif [ "$GL_MANAGER" = "nuget" ]; then GL_LANG=".NET"
else GL_LANG="$GL_MANAGER"
fi

echo "**************************************************************************************************"
echo "*** Dependabot CLI server: $2$3, authenticated as: $4"
echo "*** Repository: $5, directory: $6, branch: $7, label: $GL_LANG, assignee id: $8"
echo "*** Using this job description:"
cat update-job.yml
echo "**************************************************************************************************"

# Dependabot will set the result in a json that will be used later to create the MRs
$DEPENDABOT_CMD update -f update-job.yml --timeout 20m > update-result.json
#cat update-result.json

# Create the MR,
./create.sh update-result.json $2$3 $5 $7 $GL_LANG $8
