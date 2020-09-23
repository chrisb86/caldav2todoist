#!/bin/sh

# caldav2todoist
# Get tasks from a calDAV server and push them to Todoist.

# Copyright 2020 Christian Baer
# http://git.debilux.org/chbaer

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Your calDAV user
caldav_login="YOUR_USERNAME"
# Your calDAV password
caldav_password="YOUR_PASSWORD"
# URL of your calDAV calendar/tasklist
caldav_url="https://example.org/remote.php/dav/calendars/user/tasklist/"

# Your Todoist API token (get it at https://todoist.com/prefs/integrations)
todoist_api_token="YOUR_TODOIST_API_TOKEN"
# Todoist API endpiont. No need to change that.
todoist_api_endpoint="https://api.todoist.com/sync/v8/sync"

## Setting up the environment.
SELF=`basename -- $0 .sh`
BASEDIR=`dirname $0`
tasks_file="${BASEDIR}/.${SELF}.tasks"
lastrun_file="${BASEDIR}/.${SELF}.lastrun"

## Timezone that's used to build timestamps for last run.
## RFC 4791 requires that calDAV  servers answer with UTC so let's keep that.
caldav_timezone="UTC"

## Check if script is already running
## Usage: checkpid
checkPID () {
  SELF_pid=$$
  SELF_pid_file="${BASEDIR}/.${SELF}.pid"

  if [ -z ${SELF_pid_file} ]; then
    # Get stored PID from file
    SELF_stored_pid=`cat ${SELF_pid_file}`

    # Check if stored PID is in use
    SELF_pid_is_running=`ps aux | awk '{print $2}' | grep ${SELF_stored_pid}`

    if [ "${SELF_pid_is_running}" ]; then
      # If stored PID is already in use, skip execution
      exit 1
    fi
  fi
  # Update PID file
  echo ${SELF_pid} > ${SELF_pid_file}
}

## Get the items from the given calDAV URL that are tasks, not completed and
## created after the last run of the script.
## Pipe the through grep and cut to get only the task contents in an array
## Usage: caldav_get_task_list
caldav_get_task_list() {
  curl --silent \
    --request REPORT \
    --header "Depth: 1" \
    --header "Content-Type: text/xml" \
    --data "<c:calendar-query xmlns:d='DAV:' xmlns:c='urn:ietf:params:xml:ns:caldav'>
    <d:prop><d:getetag /><c:calendar-data /></d:prop>
    <c:filter>
    <c:comp-filter name='VCALENDAR'>
    <c:comp-filter name='VTODO'>
    ${LASTRUN}
    <c:prop-filter name='COMPLETED'>
    <c:is-not-defined/>
    </c:prop-filter>
    </c:comp-filter>
    </c:comp-filter>
    </c:filter>
    </c:calendar-query>" \
    --user "${caldav_login}:${caldav_password}" \
    ${caldav_url} | \
    grep "SUMMARY" | \
    cut -f 2 -d : >> ${tasks_file}
}

## Create a UUID and a Temp-ID for the task.
## Use curl to make an API call and create the task in Todoist.
## Suppress output except there is an error.
## Usage: todoist_add
todoist_add() {
  ## Create a UUID and a Temp-ID for the task
  task_uuid=`uuidgen`
  task_tempid=`uuidgen`

  task_query="{ \"type\": \"item_add\", \
                \"temp_id\": \"${task_tempid}\", \
                \"uuid\": \"${task_uuid}\", \
                \"args\": { \"content\": \"${task}\" } \
              }"

  curl --silent --show-error --output /dev/null --fail \
    ${todoist_api_endpoint} \
    -d token="${todoist_api_token}" \
    -d commands="[${task_query}]"
}

## Let's start the hustle
checkPID

## Check if we've been running before and get the timestamp of the last run
if [ -f ${lastrun_file} ]; then
  TIMESTAMP_LAST=`cat ${lastrun_file}`
  LASTRUN="<c:prop-filter name='CREATED'>
  <c:time-range start='${TIMESTAMP_LAST}'/>
  </c:prop-filter>"
fi

## Build the current timestamp (mind the T and Z chars!)
TIMESTAMP_NOW=`TZ=":${caldav_timezone}" date +"%Y%m%dT%H%M%SZ"`

caldav_get_task_list

## Continue if the list is not empty
## Push every task to todoist
if [ -s "${tasks_file}" ]; then
  touch ${tasks_file}.tmp
  while read task
  do
    ## Create task at todoist and keep the task in buffer if it fails
    todoist_add || echo ${task} >> ${tasks_file}.tmp
  done < ${tasks_file}
  mv ${tasks_file}.tmp ${tasks_file}
fi

## Update the timestamp of the last run
echo ${TIMESTAMP_NOW} > ${lastrun_file}
