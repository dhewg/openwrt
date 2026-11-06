#!/bin/sh
#
# dsl_notify.sh — bridge between rbctl-dsl and the OpenWrt hotplug system.
#
# The daemon forks this script with DSL_NOTIFICATION_TYPE and
# DSL_INTERFACE_STATUS (or DSL_TC_LAYER_STATUS) environment variables set.
# This script just forwards to the standard hotplug-call mechanism.
#
# Install as /sbin/dsl_notify.sh

exec /sbin/hotplug-call dsl
