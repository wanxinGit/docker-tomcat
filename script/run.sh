#!/bin/bash

set -e

${TOMCAT_HOME}/bin/startup.sh

tail -F ${TOMCAT_HOME}/logs/catalina.out