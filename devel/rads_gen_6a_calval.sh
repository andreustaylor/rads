#!/bin/bash
#-----------------------------------------------------------------------
# Copyright (c) 2011-2020  Remko Scharroo
# See LICENSE.TXT file for copying and redistribution conditions.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#-----------------------------------------------------------------------
#
# Convert Sentinel-6A files to RADS
#
# The data from <directory>/<type>/<cycle(s)> will be processed and put
# into RADS.
# Files will be created in
# $RADSDATAROOT/6a.<type>0 - Unadultered files
# $RADSDATAROOT/6a.<type>1 - RADSified files
#
# syntax: rads_gen_6a_calval.sh <directory>/<types>/<cycles(s)>
#-----------------------------------------------------------------------
. rads_sandbox.sh

# Determine type
dir=$(dirname $1)
case $dir in
*LR/*) type=lr ;;
*HR/*) type=hr ;;
esac
case $dir in
*/NR) type=${type}nr ;;
*/ST) type=${type}st ;;
*/NT) type=${type}nt ;;
esac
case $dir in
*OPE/*) type=${type}o ;;
*VAL/*) type=${type}v ;;
esac

# Process "unadultered" files
dir=6a.${type}0
rads_open_sandbox "$dir"

date													>  "$log" 2>&1

find "$@" -name "*RED*.nc" | sort		> "$lst"
rads_gen_s6 	$options --min-rec=6 < "$lst"			>> "$log" 2>&1
rads_close_sandbox

# Now process do the same again, and do the post-processing
dir=6a.${type}1
rads_open_sandbox $dir

date													>  "$log" 2>&1

find "$@" -name "*RED*.nc" | sort		> "$lst"
rads_gen_s6 	  $options --min-rec=6 < "$lst"			>> "$log" 2>&1

# Make fixes
# Range bias = 2 * 0.528 (flipped sign) - 0.045 (characterisation error, NRT only)
case $type in
	*nr*) range_bias=1.011 ;;
	   *) range_bias=1.056 ;;
esac
# Sigma0 bias = -7.40 (correct HR for observed LR/HR difference)
case $type in
	*lr*) rads_fix_s6	$options --range=$range_bias 	>> "$log" 2>&1 ;;
	   *) rads_fix_s6	$options --range=$range_bias --sig0=-7.40 --wind	>> "$log" 2>&1
	      rads_add_ssb	$options -Vssb_ku				>> "$log" 2>&1 ;;
esac

# Add MOE orbit (for NRT only)
case $type in
	*nr*) rads_add_orbit  $options -Valt_gdrf --dir=moe_doris	>> "$log" 2>&1 ;;
esac

# General geophysical corrections
rads_add_common   $options								>> "$log" 2>&1
rads_add_iono     $options --all						>> "$log" 2>&1
rads_add_mog2d    $options								>> "$log" 2>&1
# Redetermine SSHA
rads_add_sla      $options								>> "$log" 2>&1

date													>> "$log" 2>&1

rads_close_sandbox
