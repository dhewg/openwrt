#!/bin/sh
#
# led_dsl.sh — DSL LED hotplug handler for rbctl-dsl.
#
# Triggered by /sbin/hotplug-call dsl (via dsl_notify.sh) whenever the
# daemon emits a DSL_INTERFACE_STATUS event. Drives the UCI-configured
# 'led_dsl' LED:
#
#   HANDSHAKE  → slow blink (500 ms on / 500 ms off)
#   TRAINING   → fast blink (200 ms on / 200 ms off)
#   UP         → solid on
#   * (DOWN)   → off
#
# UCI LED configuration (system config):
#
#   config led 'led_dsl'
#       option sysfs   '<sysfs-name>'     # e.g. 'dsl'

[ "$DSL_NOTIFICATION_TYPE" = "DSL_INTERFACE_STATUS" ] || exit 0

. /lib/functions.sh
. /lib/functions/leds.sh

config_load system
led="$(config_get led_dsl sysfs)"

[ -n "$led" ] || exit 0

case "$DSL_INTERFACE_STATUS" in
	"HANDSHAKE")  led_timer "$led" 500 500 ;;
	"TRAINING")   led_timer "$led" 200 200 ;;
	"UP")         led_on "$led" ;;
	*)            led_off "$led" ;;
esac
