#!/bin/sh

cpp -traditional-cpp < midi2cfg-ng.conf.cpp | grep -v ^# > midi2cfg-ng.conf
