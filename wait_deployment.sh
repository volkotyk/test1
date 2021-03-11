#!/bin/bash
set -euo pipefail
SLACK=https://hooks.slack.com/services/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
RELEASE_NAME="jx-staging"
NAMESPACE="jx-staging"

# Set the helm context to the same as the kubectl context
#KUBE_CONTEXT=$(kubectl config current-context)

echo 'LOG: Watching for successful release...'

# Timeout after 20 mins (to leave time for migrations)
timeout=120
counter=0

# While $counter < $timeout
while [ $counter -lt $timeout ]; do
    echo $BUILD_ID -----------------------------------
    # Fetch all pods tagged with the release
    release_pods="$(kubectl get pods \
        -o 'custom-columns=NAME:.metadata.name,STATUS:.status.phase' \
        -n "${NAMESPACE}" \
        --no-headers \
    )"

    # If we have any failures, then the release failed
    if echo "${release_pods}" | grep -qE 'Failed'; then
      echo "LOG: ${RELEASE_NAME} failed. Check the pod logs."
      curl -X POST -H "Content-Type: application/json" -d \
	        '{"text": ":x: '$VERSION' - STEP: Check pods - Promotion to Staging is Failed"}' ${SLACK}
      exit 1
    fi

    # Are any of the pods _not_ in the Running/Succeeded status?
    if echo "${release_pods}" | grep -qvE 'Running|Succeeded'; then

        echo "${release_pods}" | grep -vE 'Running|Succeeded'
        echo "${RELEASE_NAME} pods not ready. ${counter}/${timeout} checks completed; retrying."

        # NOTE: The pre-increment usage. This makes the arithmatic expression
        # always exit 0. The post-increment form exits non-zero when counter
        # is zero. More information here: http://wiki.bash-hackers.org/syntax/arith_expr#arithmetic_expressions_and_return_codes
        ((++counter))
        sleep 10
    else
        #All succeeded, we're done!
        echo "${release_pods}"
        echo "LOG: All ${RELEASE_NAME} pods running and jobs succeeded. Done!"
        curl -X POST -H "Content-Type: application/json" -d \
	'{"text": ":thumbsup: <https://dash.favedom-dev.softcannery.com/teams/jx/projects/favedom-dev/environment-favedom-dev-staging/master/'$BUILD_ID'|'$VERSION'> - Pods running and jobs succeeded. Done!"}' ${SLACK}
        exit 0
    fi
done

# We timed out
echo "LOG: Release ${RELEASE_NAME} did not complete in time" 1>&2
curl -X POST -H "Content-Type: application/json" -d \
	        '{"text": ":x: '$VERSION' - STEP: Check pods - Release did not complete in time"}' ${SLACK}
exit 1
