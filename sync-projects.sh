#!/usr/bin/env bash

# Clone/pull all repos which are not archived from the given group path ($1).
# Gitlab API documentation: https://docs.gitlab.com/ce/api/projects.html#list-projects

GROUP_PATH="$1"
BASE_PATH="https://gitlab.example.com/"
PROJECT_PROJECTION="{ "path": .path_with_namespace, "git": .ssh_url_to_repo }"

if [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
    echo "Please set the environment variable GITLAB_PRIVATE_TOKEN"
    echo "See ${BASE_PATH}profile/account"
    exit 1
fi

REPOS="repos.json"
ARCHIVED_REPOS="archived_repos.json"
trap "{ rm -f $REPOS $ARCHIVED_REPOS; }" EXIT

curl --request GET --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -s "${BASE_PATH}api/v4/projects/?per_page=999&archived=true" \
    | jq --raw-output --compact-output ".[] | select(.path_with_namespace | contains(\"$GROUP_PATH\")) | $PROJECT_PROJECTION" > "$ARCHIVED_REPOS"

curl --request GET --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
    -s "${BASE_PATH}api/v4/groups/$GROUP_PATH/search?scope=projects&search=&per_page=999" \
    | jq --raw-output --compact-output ".[] | $PROJECT_PROJECTION" > "$REPOS"

while read repo; do
    REPO_PATH=$(echo "$repo" | jq -r ".path")
    PARENT_PATH=$(dirname "$REPO_PATH")
    GIT=$(echo "$repo" | jq -r ".git")

    if grep -q $GIT "$ARCHIVED_REPOS"; then
        echo "Skipping archived repo: $GIT"
        continue
    fi

    if [ ! -d "$REPO_PATH" ]; then
        echo "Cloning $REPO_PATH ( $GIT )"
        mkdir -p $PARENT_PATH
        (cd $PARENT_PATH && git clone "$GIT" --quiet)
    else
        echo "Pulling $REPO_PATH ( $GIT )"
        (cd "$REPO_PATH" && git pull --quiet)
    fi

done < "$REPOS"

wait
