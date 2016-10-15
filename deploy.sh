#!/usr/bin/env bash

rev=$(git rev-parse --short HEAD)

cd public
rm .gitignore

git init
git config user.name "Travis CI"
git config user.email "travis@arapaima.uk"

git remote add upstream "https://$GH_TOKEN@github.com/arapaima-uk/arapaima-uk.github.io.git"
git fetch upstream
git reset upstream/master

echo "arapaima.uk" > CNAME

touch .

git add -A .
git commit -m "rebuild pages at ${rev}"
git push -q upstream HEAD:master


