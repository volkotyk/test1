JENKINS_X_CHARTMUSEUM := http://jenkins-x-chartmuseum:8080
CHART_REPO := $(or $(CHART_REPOSITORY),$(JENKINS_X_CHARTMUSEUM))
DIR := "env"
NAMESPACE := "jx-staging"
OS := $(shell uname)
HELM := $(or $(HELM),./helm3)
HELM_VERSION := v3.3.4
HELMFILE := ./helmfile
HELMFILE_VERSION := v0.138.4
HELM_DIFF_VERSION := 3.1.3
INSTALL := ${HELM} upgrade ${NAMESPACE} ${DIR} --install --namespace ${NAMESPACE} --create-namespace
HELMFILE_APPLY := ${HELMFILE} apply --skip-deps --skip-diff-on-install

REPORT_UI := <https://dash.favedom-dev.softcannery.com/teams/jx/projects/favedom-dev/environment-favedom-dev-staging/master/${BUILD_ID}|${VERSION}>

SLACK := https://hooks.slack.com/services/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
SLACK_STEP := if [[ "${VERSION}" != *"SNAPSHOT-PR"* ]]; then if [ $$EXIT_CODE -ne 0 ]; \
	then curl -X POST -H "Content-Type: application/json" -d \
	'{"text": ":x: '${VERSION}' - STEP: '$$STEP_NAME' - Promotion to Staging is Failed"}' ${SLACK} && \
	 exit $$EXIT_CODE; \
	 else curl -X POST -H "Content-Type: application/json" -d \
	 '{"text": ":white_check_mark: '${VERSION}' - Step '$$STEP_NAME'"}' ${SLACK}; fi; else exit $$EXIT_CODE; fi
SLACK_START := if [[ "${VERSION}" != *"SNAPSHOT-PR"* ]]; then curl -X POST -H "Content-Type: application/json" -d \
	'{"text": ":rocket: <https://dash.favedom-dev.softcannery.com/teams/jx/projects/favedom-dev/environment-favedom-dev-staging/master/'${BUILD_ID}'|'${VERSION}'> - Staging Pipeline is started - <https://github.com/favedom-dev/environment-favedom-dev-staging/commit/'${PULL_BASE_SHA}'|commit>"}' ${SLACK}; fi
SLACK_FINISH := if [[ "${VERSION}" != *"SNAPSHOT-PR"* ]]; then curl -X POST -H "Content-Type: application/json" -d \
	'{"text": ":thumbsup: Staging Pipeline is finished, version - <https://dash.favedom-dev.softcannery.com/teams/jx/projects/favedom-dev/environment-favedom-dev-staging/master/'${BUILD_ID}'|'${VERSION}'>"}' ${SLACK}; fi

sed:
	sed -i 's|$(JENKINS_X_CHARTMUSEUM)|$(CHART_REPO)|g' ./${DIR}/requirements.yaml

build: clean sed
	which helm3
	${HELM} version
	${HELMFILE} build && \
	${HELMFILE} deps --skip-repos && \
	${HELMFILE} repos; \
	EXIT_CODE=$$?; STEP_NAME="build-helm-lint";\
	${SLACK_STEP}

init:
	${SLACK_START}
	wget --quiet -O helmfile_linux_amd64 https://github.com/roboll/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64;\
	mv helmfile_linux_amd64 ${HELMFILE};\
	chmod +x ${HELMFILE};\
	wget --quiet https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz;\
	tar -xvf helm-${HELM_VERSION}-linux-amd64.tar.gz;\
	mv linux-amd64/helm ${HELM};\
	rm -rf ./linux-amd64 ./*.tar.*;\
	${HELM} plugin install https://github.com/databus23/helm-diff --version=${HELM_DIFF_VERSION};\
	EXIT_CODE=$$?; STEP_NAME=init;\
	${SLACK_STEP}


install: 
	${HELMFILE_APPLY};\
	EXIT_CODE=$$?; STEP_NAME="helm-upgrade";\
	${SLACK_STEP}

dry-run:
	${HELMFILE_APPLY} --args --dry-run;\
	EXIT_CODE=$$?; STEP_NAME="helm-upgrade-dry-run";\
	${SLACK_STEP}

uninstall:
	${HELM} uninstall ${NAMESPACE} --namespace ${NAMESPACE}

clean:
	rm -rf ./${DIR}/requirements.lock

test:

test-configure:
	git config --global credential.helper store
	jx step git credentials
	git clone https://github.com/favedom-dev/automation.git

test-ui-fan:
	cd automation && ./gradlew clean build test --tests 'ui.fan.tests.*' -Dchromeoptions.args=--no-sandbox

test-ui-celeb:
	cd automation && ./gradlew clean build test --tests 'ui.celeb.tests.*' -Dchromeoptions.args=--no-sandbox

test-api:
	cd automation && ./gradlew clean build test --tests 'api.tests.*'

test-rabbitmq-sms:
	cd automation && ./gradlew clean build test --tests 'rabbitmq.tests.*' -Dchromeoptions.args=--no-sandbox

test-jmeter:
	cd automation && apache-jmeter-5.3/bin/jmeter -t jmx/Celeb_Moder_Fan_TestPlan_v1.jmx -q jmx/properties/auto.properties -n && echo $?
