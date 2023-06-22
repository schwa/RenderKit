#!/bin/sh
PATH=$PATH:/opt/homebrew/bin:/opt/brew/bin
cd ..
if command -v swiftlint > /dev/null
then
    #echo "# Running swiftlint"
    swiftlint --quiet --lenient
fi

#if command -v swiftformat > /dev/null
#then
#    swiftformat -lint . || true
#fi
