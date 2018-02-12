DEV_IMAGE_ORG = jboss-dataservices
DOCKER_REGISTRY_ENGINEERING =
DOCKER_REGISTRY_REDHAT =
DEV_IMAGE_NAME = infinispan-server-dev
TESTRUNNER_IMAGE_NAME = wildfly11-testrunner

CE_DOCKER = $(shell docker version | grep Version | head -n 1 | grep -e "-ce")
ifneq ($(CE_DOCKER),)
DOCKER_REGISTRY_ENGINEERING = docker-registry.engineering.redhat.com
DOCKER_REGISTRY_REDHAT = registry.access.redhat.com/
endif

MVN_COMMAND = mvn
_TEST_PROJECT = myproject
_APP_NAME = my-app
_DOCKER_REGISTRY = $(OPENSHIFT_ONLINE_REGISTRY)
_IMAGE = $(_DOCKER_REGISTRY)/$(_TEST_PROJECT)/$(DEV_IMAGE_NAME)
_TESTRUNNER_IMAGE = $(_DOCKER_REGISTRY)/$(_TEST_PROJECT)/$(TESTRUNNER_IMAGE_NAME)
_TESTRUNNER_PORT = 80

build-image:
	sudo docker build -t $(DEV_IMAGE_NAME) ./infinispan-server
	sudo docker build -t $(TESTRUNNER_IMAGE_NAME) ./wildfly11-testrunner
.PHONY: build-image

_login_to_docker:
	sudo docker login -u $(shell oc whoami) -p $(shell oc whoami -t) $(_DOCKER_REGISTRY)
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

test-functional: deploy-testrunner-route
	$(MVN_COMMAND) -Dkubernetes.auth.token=$(shell oc whoami -t) -DTESTRUNNER_HOST=$(shell oc get routes | grep testrunner | awk '{print $$2}') -DTESTRUNNER_PORT=${_TESTRUNNER_PORT} clean test -f functional-tests/pom.xml
.PHONY: test-functional

deploy-testrunner-route:
	oc create -f ./functional-tests/src/test/resources/wildfly11-testrunner-service.json
	oc create -f ./functional-tests/src/test/resources/wildfly11-testrunner-route.json
.PHONY: deploy-testrunner-route

clean-maven:
	$(MVN_COMMAND) clean -f functional-tests/pom.xml || true
.PHONY: clean-maven

test-remote: clean-maven prepare-openshift-project build-image push-image-to-online-openshift create-app test-functional
.PHONY: test-online
