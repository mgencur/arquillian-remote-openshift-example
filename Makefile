DEV_IMAGE_NAME = infinispan-server-dev
TESTRUNNER_IMAGE_NAME = wildfly11-testrunner

MVN_COMMAND = mvn
_TEST_PROJECT = myproject
_APP_NAME = my-app
_IMAGE = $(DOCKER_REGISTRY)/$(_TEST_PROJECT)/$(DEV_IMAGE_NAME)
_TESTRUNNER_IMAGE = $(DOCKER_REGISTRY)/$(_TEST_PROJECT)/$(TESTRUNNER_IMAGE_NAME)
_TESTRUNNER_PORT = 80

build-image:
	sudo docker build -t $(DEV_IMAGE_NAME) ./infinispan-server
	sudo docker build -t $(TESTRUNNER_IMAGE_NAME) ./wildfly11-testrunner
.PHONY: build-image

_login_to_docker:
	sudo docker login -u $(shell oc whoami) -p $(shell oc whoami -t) $(DOCKER_REGISTRY)
.PHONY: _login_to_docker

push-image-common:
	@echo "---- Pushing my test image ----"
	sudo docker tag $(DEV_IMAGE_NAME) $(_IMAGE)
	sudo docker push $(_IMAGE)
	oc set image-lookup $(DEV_IMAGE_NAME)
	@echo "---- Pushing WildFly test runner image ----"
	sudo docker tag $(TESTRUNNER_IMAGE_NAME) $(_TESTRUNNER_IMAGE)
	sudo docker push $(_TESTRUNNER_IMAGE)
	oc set image-lookup $(TESTRUNNER_IMAGE_NAME)
.PHONY: push-image-common

push-image-to-online-openshift: _login_to_docker push-image-common
.PHONY: push-image-to-online-openshift

prepare-openshift-project: clean-openshift
	@echo "---- Create main project for test purposes"
	oc new-project $(_TEST_PROJECT)

	@echo "---- Switching to test project ----"
	oc project $(_TEST_PROJECT)
.PHONY: prepare-openshift-project

clean-openshift:
	@echo "---- Deleting projects ----"
	oc delete project $(_TEST_PROJECT) || true
	( \
		while oc get projects | grep -e $(_TEST_PROJECT) > /dev/null; do \
			echo "Waiting for deleted projects..."; \
			sleep 5; \
		done; \
	)
.PHONY: clean-openshift

create-app:
	@echo "---- Creating application using image stream ----"
	oc new-app $(DEV_IMAGE_NAME) -e "APP_USER=user" -e "APP_PASS=changeme"
.PHONY: create-app

test-functional:
	$(MVN_COMMAND) -Dkubernetes.auth.token=$(shell oc whoami -t) clean test -f functional-tests/pom.xml
.PHONY: test-functional

clean-maven:
	$(MVN_COMMAND) clean -f functional-tests/pom.xml || true
.PHONY: clean-maven

test-remote: clean-maven prepare-openshift-project build-image push-image-to-online-openshift create-app test-functional
.PHONY: test-online
