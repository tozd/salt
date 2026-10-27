#!/bin/bash -e
# ------------------------------------------------------------------------
# THIS FILE HAS BEEN AUTOMATICALLY GENERATED VIA SALT-BASED CONFIGURATION.
# ANY MANUAL CHANGES WILL BE OVERWRITTEN!
# ------------------------------------------------------------------------

export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

# Every pull of a newer version of an image leaves the previous one behind without a tag. This removes such images which
# no container uses. Docker reports the reclaimed space even when there is none, so only errors are shown.
docker image prune --force > /dev/null

# Data which has to be retained lives in bind mounts and never in volumes, so every volume which no container uses is
# removed. Docker 23 and newer remove only anonymous volumes unless given --all, which older versions do not have because
# they always remove all of them.
if docker volume prune --help | grep -q -- '--all'; then
  docker volume prune --force --all > /dev/null
else
  docker volume prune --force > /dev/null
fi
