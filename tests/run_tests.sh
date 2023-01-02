#!/bin/bash

cd `dirname $0`

echo "Running:" >&2

if [ -z "$DOCKER_REGISTRY_IMAGE" ]
then
  echo "Please set \$DOCKER_REGISTRY_IMAGE to the docker image under test"
  exit 1
fi

FAILED_TESTS=0
TOTAL_TESTS=0
SUCCESSFUL_TESTS=0
while read line
do
  if [ ! -z "$line" ];
  then
    echo -n " - $line" >&2
    if [ -f message.txt ]
    then
      rm message.txt
    fi
    ./$line 2>message.txt
    if [ "$?" == 0 ]
    then
      let "SUCCESSFUL_TESTS += 1"
      echo " [ok]" >&2
    else
      let "FAILED_TESTS += 1"
      echo " [fail]" >&2
    fi
    if [ -f message.txt ]
    then
      if [ ! -z "`cat message.txt`" ]
      then
        echo -n "    "
        cat message.txt
      fi
      rm message.txt
    fi
    let "TOTAL_TESTS += 1"
  fi
done<<EOF
`ls | grep "^test_"`
EOF

echo "Successful tests: $SUCCESSFUL_TESTS / $TOTAL_TESTS" >&2

if [ "$FAILED_TESTS" != "0" ]
then
 exit 1
fi

exit 0