#!/bin/bash

set -e
set -x

if [ -z "$INPUT_SOURCE_PATH" ]
then
  echo "Source path must be defined"
  exit -1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master"]
then
  echo "Destination head branch cannot be 'main' nor 'master'"
  exit -1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

CLONE_DIR=$(mktemp -d)

echo "Setting git variables"
export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

echo "Cloning destination git repository"
git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Checking if branch already exists"
set +e
pushd "$CLONE_DIR"
git checkout "$INPUT_DESTINATION_HEAD_BRANCH"
BRANCH_ALREADY_EXISTS=$?
popd
set -e

echo "Copying contents to git repo"
cp -r $INPUT_SOURCE_PATH "$CLONE_DIR/$INPUT_DESTINATION_PATH"
cd "$CLONE_DIR"
if [ $BRANCH_ALREADY_EXISTS -ne 0 ]
then
  git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"
fi

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
  echo "Pushing git commit"
  git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
  echo "Creating a pull request"
  echo -n "pr_url=" >> $GITHUB_OUTPUT

  set +e
  gh pr create -t "$INPUT_TITLE" \
               -b "$INPUT_BODY" \
               -B $INPUT_DESTINATION_BASE_BRANCH \
               -H $INPUT_DESTINATION_HEAD_BRANCH \
               -l $INPUT_LABEL \
                  $PULL_REQUEST_REVIEWERS >> $GITHUB_OUTPUT

  if [ $? -ne 0 ]
  then
    echo "created=false" >> $GITHUB_OUTPUT
    echo "Failed to create pull request"
    # if the branch already existed then it's ok that we couldn't create the PR because it was probably already created
    exit $BRANCH_ALREADY_EXISTS
  else
    echo "created=true" >> $GITHUB_OUTPUT
    echo "Pull request created"
  fi
else
  echo "No changes detected"
fi
