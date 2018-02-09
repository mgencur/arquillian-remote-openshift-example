#!/bin/bash

echo "---- Clearing up test resources ---"
oc delete service testrunner || true
oc delete route testrunner || true


