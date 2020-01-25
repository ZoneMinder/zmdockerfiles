#~/bin/bash
################################################################################
# Date of last revision: 12/29/19
#
# This script:
# - retrieves zoneminder source from github
# - builds arm packages using packpack
# - rsync results to zmrepo.zoneminder.com
#
################################################################################

# Arbitrary location to save zoneminder git HEAD
HEAD="/home/youraccount/HEAD"

# Parent folder to save ZoneMinder source from github
GIT_HOME="/home/youraccount/git"

# Enter your personal Git token
# See: https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line
GIT_TOKEN="abcdefghijklmnopqrstuvwxyz0123456789"

MKDIR="/bin/mkdir"
RSYNC="/usr/bin/rsync"
CP="/bin/cp"
FIND="/usr/bin/find"
GIT="/usr/bin/git"
RM="/bin/rm"
LS="/bin/ls"
CURL="/usr/bin/curl"
CAT="/bin/cat"
JQ="/usr/bin/jq"
TOUCH="/usr/bin/touch"

# Check to see if this script has access to all the commands it needs
for CMD in set echo $MKDIR $RSYNC $CP $FIND $GIT $RM $LS $CURL $CAT $JQ $TOUCH; do
  type $CMD &> /dev/null

  if [ $? -ne 0 ]; then
    echo
    echo "ERROR: The script cannot find the required command \"${CMD}\"."
    echo
    exit 1
  fi
done

###############
# SUBROUTINES #
###############

#
# subroutine to pull lastest html source from github
#

git_update () {
  GIT_ZONEMINDER="$GIT_HOME/zoneminder"

  if [ -d "$GIT_ZONEMINDER"  ]; then
    cd "$GIT_ZONEMINDER"
    $GIT checkout master
    $GIT pull origin master
  else
    $MKDIR -p "$GIT_HOME"
    cd "$GIT_HOME"
    $GIT clone https://github.com/ZoneMinder/zoneminder
    cd zoneminder
  fi

}

#
# subroutine to run packpack then rsync the results
#

start_packpack () {

  $RM -rf ./build

  ./utils/packpack/startpackpack.sh

  if [ "$?" -eq 0 ]; then
      echo
      echo "SUCCESS: ${OS} ${DIST} build completed."
      echo "Transferring packages to zmrepo..."
      echo
      rsync_xfer
  else
      echo
      echo "ERROR: ${OS} ${DIST} build failed."
      echo
      ((build_error++))
  fi
}

#
# subroutine to rsync files to zmrepo
#

rsync_xfer () {

  if [ "${OS}" == "debian" ] || [ "${OS}" == "ubuntu" ] || [ "${OS}" == "raspbian" ]; then
    targetfolder="debian/master/mini-dinstall/incoming"
  else
    targetfolder="travis"
  fi

  $RSYNC --ignore-missing-args --exclude 'external-repo.noarch.rpm' build/*.{rpm,deb,dsc,tar.xz,buildinfo,changes} zmrepo@zmrepo.zoneminder.com:${targetfolder}/ 2>&1

  if [ "$?" -eq 0 ]; then
    echo 
    echo "SUCCESS: Packages transferred successfully."
    echo
  else 
    echo
    echo "ERROR: Attempt to rsync to zmrepo.zoneminder.com failed!"
    echo
    ((rsync_error++))
  fi

}

################
# MAIN PROGRAM #
################

# Verify the provided github token is good
result=$(${CURL} -s -H "Authorization: token ${GIT_TOKEN}" https://api.github.com/ | ${JQ} -r ".message")
if [ "$result" == "Bad credentials"]; then
  echo
  echo "FATAL: Github token appears to be invalid."
  echo
  exit 99
fi

# pre-loop init
build_error=0
rsync_error=0
shopt -s nullglob

echo
echo "Waiting for new changes to the ZoneMinder github repo..."
echo

while true; do

  if [ ! -f "${HEAD}"  ]; then
    $TOUCH "${HEAD}"
  fi

  local_head=$(${CAT} ${HEAD})
  remote_head=$(${CURL} -H "Authorization: token ${GIT_TOKEN}" -s 'https://api.github.com/repos/ZoneMinder/zoneminder/git/refs/heads/master' | ${JQ} -r '.object.sha')

  if [ "${local_head}" != "${remote_head}" ] && [ "${remote_head}" != "null"  ]; then

    ## STEP 1 - Pull latest ZoneMinder changes from github
    git_update

    ## STEP 2 - Start PackPack builds, one at a time

    OS=fedora DIST=30 DOCKER_REPO=knnniggett/packpack ARCH=armhf start_packpack

    OS=fedora DIST=31 DOCKER_REPO=knnniggett/packpack ARCH=armhf start_packpack

    OS=ubuntu DIST=xenial DOCKER_REPO=knnniggett/packpack ARCH=armhf start_packpack

    OS=ubuntu DIST=bionic DOCKER_REPO=knnniggett/packpack ARCH=armhf start_packpack

    ## STEP 3 - Report build summary
    if [ $build_error -eq 0 ] && [ $rsync_error -eq 0 ]; then
      echo
      echo "SUCCESS: All builds reported completion."
      echo
    else
      if [ $build_error -gt 0 ]; then
        echo
        echo "ERROR: ${build_error} builds failed!"
        echo
        build_error=0
      fi
      if [ $rsync_error -gt 0 ]; then
        echo
        echo "ERROR: ${rsync_error} rsync transfers failed!"
        echo
        rsync_error=0
      fi          
    fi

    # Update HEAD with the latest git commit hash
    echo "${remote_head}" > "${HEAD}"
    echo
    echo "FINISHED: Waiting for new changes to the ZoneMinder github repo..."
    echo

  elif [ "${remote_head}" == "null"  ]; then
      echo
      echo "ERROR: Failed to retrive latest zoneminder commit hash from github."
      echo "Check Internet conectivity."
      echo
  fi

  sleep 1m
done

