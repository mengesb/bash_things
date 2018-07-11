#!/usr/bin/env bash

# -----------------------------------------------------------------------------
VERSION=1.0
AUTHOR="Brian Menges"
AUTHOR_EMAIL="mengesb@gmail.com"
LICENSE="Apache 2.0"
LICENSE_URL="http://www.apache.org/licenses/LICENSE-2.0"
# -----------------------------------------------------------------------------

# Usage
usage()
{
  cat <<EOF

  usage: bash $0 [OPTIONS]

  This script will attempt to download a version of CHEF Server specified
  from packagecloud.io in the most awful way possible.

  SYMANTICS NOTE:
  This script supports RedHat, CentOS and Ubuntu. Since CHEF versions these
  distributions differently, I've followed them making this a fun endeavor.

  Ubuntu release versions are their code name. RedHat/CentOS follow
  'Enterprise Linux' naming of 'el' and the major release number.

  REQUIRED OPTIONS:
  -c  CHEF stable version    ex. latest   = current stable version
                                 12       = greatest 12.x.y-z version
                                 12.2     = greatest 12.2.y-z version
                                 12.2.1   = greatest 12.2.1-z version
                                 12.4.1-1 = explicit version
  -o  OS name                ex. el or ubuntu
  -r  OS release name        ex. 6 or trusty

  OPTIONAL OPTIONS:
  -d  Destination directory  ex. /tmp (default)
  -h  This help message
  -v  Verbose output

  Licensed under ${LICENSE} (${LICENSE_URL})
  Author : ${AUTHOR} <${AUTHOR_EMAIL}>
  Version: ${VERSION}

EOF
}

# Requirements check
d_directory=/tmp
VAR=$(echo "$BASH_VERSION")
[[ $? -ne 0 ]] && echo "Unable to determine BASH version installed, exiting." && usage && exit 1
[[ "${BASH_VERSION}" =~ ^[0-3] ]] && echo "Script requires a BASH version 4.x or higher, found ${BASH_VERSION}" && usage && exit 1
[[ -z "$(grep --version)" ]] && echo "Program 'grep' not found in PATH!" && usage && exit 1
[[ -z "$(sort --version)" ]] && echo "Program 'sort' not found in PATH!" && usage && exit 1
[[ -z "$(curl --version)" ]] && echo "Program 'curl' not found in PATH!" && usage && exit 1
[[ -z "$(which mktemp)" ]] && echo "Program 'mktemp' not found in PATH!" && usage && exit 1

# Options parsing
while getopts "c:o:r:d:hv" OPTION; do
  case "$OPTION" in
    c)
      if [[ "$OPTARG" =~ ^(([0-9]+(\.[0-9]+(\.[0-9]+)?)?)(-[0-9]+)?)$ ]]; then
      #  c_ver=$OPTARG
        c_version=${BASH_REMATCH[1]}
      #elif [[ "$OPTARG" =~ [0-9]+\.[0-9]+\.[0-9]+-[0-9]+ ]]; then
      #  c_ver=$OPTARG
      elif [[ "${OPTARG,,}" =~ ^(latest)$ ]]; then
        c_version=${OPTARG,,}
      else
        echo "ERROR: Specified version invalid!"
        usage && exit 1
      fi
      ;;
    o)
      if [[ "${OPTARG,,}" =~ (el|ubuntu) ]]; then
        o_version=$OPTARG
      elif [[ "${OPTARG,,}" =~ (centos|redhat) ]]; then
        o_version=el
      elif [[ "${OPTARG,,}" =~ (el|centos|rh|redhat)[0-9]+ ]]; then
        o_version=el
      else
        echo "ERROR: Specified OS name invalid!"
        usage && exit 1
      fi
      ;;
    r)
      if [[ "${OPTARG,,}" =~ [0-9a-z]+ ]]; then
        r_version=${OPTARG,,}
      fi
      ;;
    d)
      if [[ -d "${OPTARG}" ]]; then
        d_directory=${OPTARG}
      fi
      ;;
    h)
      usage && exit 0
      ;;
    v)
      VERBOSE=1
      ;;
    *)
      usage && exit 1
      ;;
    ?)
      usage && exit 1
      ;;
  esac
done

# Options c, o, and r are required options
[[ -z "${c_version}" ]] && echo "ERROR: Required option missing: -c [CHEF Server Version]" && usage && exit 1
[[ -z "${o_version}" ]] && echo "ERROR: Required option missing: -o [OS]" && usage && exit 1
[[ -z "${r_version}" ]] && echo "ERROR: Required option missing: -r [OS Release Code]" && usage && exit 1

# Case to handle ubuntu
if [[ "${o_version}" == "ubuntu" ]] && [[ "${r_version}" =~ [0-9]+ ]]; then
  echo "ERROR: Provide release code name for Ubuntu instead of the version number"
  echo "ERROR: ex. trusty"
  echo ""
  usage && exit 1
fi

# Generate some temp files necessary for future operations
TMPFILE1=$(mktemp /tmp/chef-server-url-list.XXXXXXXX)
TMPFILE2=$(mktemp /tmp/chef-server-url-list.XXXXXXXX)
TMPFILE3=$(mktemp /tmp/chef-server-url-list.XXXXXXXX)

# Variables to construct REGEX searching
URLBASE="https://packagecloud.io/chef/stable/packages"
OSREGEX="(el|ubuntu)/([0-9]+|[a-z]+)"
PKREGEX="(chef-server-core)(-|_)([0-9]+(\.[0-9]+){2}(-[0-9]+)?)(\.ubuntu\.|\.el)?([0-9]+(\.[0-9]+)?)?(_amd|\.x86_)64\.(rpm|deb)"

# Aggregate REGEX syntax variable to prevent excessively long lines
REGEX_MATCH="${URLBASE}/${OSREGEX}/${PKREGEX}/download"

# Get HTML page containing download URLs and parse file using grep
curl -s -o $TMPFILE1 https://downloads.chef.io/chef-server/redhat/
grep -Eo "$REGEX_MATCH" $TMPFILE1 | sort -r | uniq > $TMPFILE2
rm $TMPFILE1

# Filter URLs parsed based on user OS and OS release constraints
while IFS='' read -r line || [[ -n "$line" ]]; do
  #echo "Line is: '$line'"
  if [[ "$line" =~ ${o_version}(/)?${r_version} ]]; then
    # echo "MATCHED: '$line'"
    echo "$line" >> $TMPFILE3
  fi
done < $TMPFILE2
rm $TMPFILE2

# URL parsing to find greatest matching version from user input
if [[ "${c_version}" == "latest" ]]; then
  CHEF_URL=$(tail -n 1 ${TMPFILE3})
else
  CHEF_URL=$(grep -m 1 "${c_version}" ${TMPFILE3})
fi
rm $TMPFILE3
[[ -z "${CHEF_URL}" ]] && echo "ERROR: CHEF Server download URL could not be found matching your inputs" && exit 1

# Download binary
CHEF_VERSION=$(echo "${CHEF_URL}" | grep -Eo "(${PKREGEX})")
curl -s -k -o ${d_directory}/${CHEF_VERSION} ${CHEF_URL}
EXIT_CODE=$?
[[ $EXIT_CODE -eq 0 ]] && [[ $VERBOSE -eq 1 ]] && echo "Downloaded ${CHEF_VERSION} to ${d_directory}/${CHEF_VERSION}"

# Exit using cURL's exit code
exit $EXIT_CODE
