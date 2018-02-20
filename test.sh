#!/usr/bin/env bash

if [ -z "$(which sit 2>/dev/null)" ]; then
    echo sit is not in PATH
    exit 1
fi

sit_cfg=$(pwd)/sit_config.json
sit="sit -c ${sit_cfg}"
echo "${sit}"

master="$(mktemp -d)"
bare_master="$(mktemp -d)/bare"
inbox="$(mktemp -d)/inbox"
submitter="$(mktemp -d)/fork"
submitter_2="$(mktemp -d)/fork"


# Create master
pushd "$(pwd)" >/dev/null || exit 2;
cd "${master}" || exit 2
git init
${sit} init
issue=$(sit issue)
${sit} record -t test "${issue}"
git add .sit
git commit -m "Initial .sit repo"
popd >/dev/null || exit

git clone --bare "${master}" "${bare_master}"

# Clone to inbox
git clone "${bare_master}" "${inbox}"
# Prepare hooks & config
cp pre-receive post-receive "${inbox}/.git/hooks"
git -C ${inbox} config sit.target "file://${bare_master}"

# Clone to submitter
git clone "${bare_master}" "${submitter}"

# Prepare a separate clone (to be intentionally outdated)
git clone "${bare_master}" "${submitter_2}"

# Good update
pushd "$(pwd)" >/dev/null || exit 2;
cd "${submitter}" || exit 2
git remote add sit "${inbox}"
git checkout -b good
new_issue=$(${sit} issue)
new_record=$(${sit} record -t test "${new_issue}")
# random file for further testing
touch .sit/issues/something
git add .sit
git commit -m "good"
git push sit "good:${new_issue}" || (echo "Pushing good commit failed"; exit 1)
good_commit=$(git rev-parse HEAD)
popd >/dev/null || exit 2

pushd "$(pwd)" >/dev/null || exit 2; cd "${master}" || exit 2
git pull "${bare_master}" master
last_commit=$(git rev-parse HEAD)
if [ "${good_commit}" != "${last_commit}" ]; then
    echo "Good commit didn't go through"
    exit 1
fi
echo "|   SUCCESS: Good commit went through"
popd >/dev/null || exit 2

# Branch deletion
pushd "$(pwd)" >/dev/null || exit 2; cd "${submitter}" || exit 2
git push sit ":${new_issue}" || (echo "Deleting branch didn't work, should pass through"; exit 1)
popd >/dev/null || exit 2

# File outside of .sit/issues
pushd "$(pwd)" >/dev/null || exit 2; cd "${submitter}" || exit 2
git fetch
git checkout -b outside origin/master
touch .sit/test
git add .sit
git commit -m "outside"
git push sit outside && (echo "Pushing bad commit succeeded"; exit 1)
echo "|   SUCCESS: File outside of .sit/issues didn't go through"
popd >/dev/null || exit 2

# Existing file change in .sit/issues
pushd "$(pwd)" >/dev/null || exit 2; cd "${submitter}" || exit 2
git fetch
git checkout -b existing origin/master
echo test > .sit/issues/something
git add .sit
git commit -m "existing"
git push sit existing && (echo "Pushing bad commit succeeded"; exit 1)
echo "|   SUCCESS: Existing file change in .sit/issues didn't go through"
popd >/dev/null || exit 2

# Adding a file to an existing record
pushd "$(pwd)" >/dev/null || exit 2; cd "${submitter}" || exit 2
git fetch
git checkout -b adding_file origin/master
touch ".sit/issues/${new_issue}/${new_record}/test"

git add .sit
git commit -m "adding file"
git push sit adding_file && (echo "Pushing bad commit succeeded"; exit 1)
echo "|   SUCCESS: Adding file to an existing record didn't go through"
popd >/dev/null || exit 2

# Adding an issue from a non-updated master
pushd "$(pwd)" >/dev/null || exit 2; cd "${submitter_2}" || exit 2
git remote add sit "${inbox}"
git checkout -b good
new_issue=$(${sit} issue)
new_record=$(${sit} record -t test "${new_issue}")
git add ".sit/issues/${new_issue}"
git commit -m "good"
git push sit "good:${new_issue}" || (echo "Pushing good commit from an outdated master fork failed"; exit 1)
popd >/dev/null || exit 2

pushd "$(pwd)" >/dev/null || exit 2; cd "${master}" || exit 2
git pull "${bare_master}" master
if [ -d .sit/issues/${new_issue}/${new_record} ]; then
    echo "OK"
else
    echo "Good commit from an outdated master fork didn't go through"
    exit 1
fi
echo "|   SUCCESS: Good commit from an outdated master fork went through"
popd >/dev/null || exit 2



echo
echo
echo
