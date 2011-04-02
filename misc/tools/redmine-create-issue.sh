#!/bin/bash

# Begin config

STATUS_ID=${STATUS_ID:-1}
PROJECT_ID=${PROJECT_ID:-8}
TRACKER_ID=${TRACKER_ID:-4}
PRIORITY_ID=${PRIORITY_ID:-4}
REDMINE_URL=${REDMINE_URL:-"http://dev.xonotic.org"}

# End config

if [ "$#" -ne "4" ];
then
	echo "Usage: $0 <user> <pass> <subject> <description>"
	exit;
fi;

USER="$1"
PASS="$2"
SUBJECT="$3"
DESCRIPTION=$(echo "$4" | sed -e 's/</\&lt;/g;s/>/\&gt;/g')

cat > CONTENTS <<EOF
<?xml version="1.0"?>
<issue>
	<status_id>${STATUS_ID}</status_id>
	<tracker_id>${TRACKER_ID}</tracker_id>
	<project_id>${PROJECT_ID}</project_id>
	<priority_id>${PRIORITY_ID}</priority_id>
	<subject>${SUBJECT}</subject>
	<description>${DESCRIPTION}</description>
	<notes></notes>
</issue>
EOF

curl -X POST -H "Content-Type:application/xml" --data "@CONTENTS" -u "${USER}:${PASS}" "${REDMINE_URL}/issues.xml" > /dev/null

rm CONTENTS

