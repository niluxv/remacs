#!/bin/sh
### autogen.sh - tool to help build Remacs from a repository checkout

## Copyright (C) 2011-2017 Free Software Foundation, Inc.

## Author: Glenn Morris <rgm@gnu.org>
## Maintainer: emacs-devel@gnu.org

## This file is part of Remacs.

## Remacs is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## Remacs is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with Remacs.  If not, see <https://www.gnu.org/licenses/>.

### Commentary:

## The Remacs repository does not include the configure script (and
## associated helpers).  The first time you fetch Remacs from the repo,
## run this script to generate the necessary files.
## For more details, see the file INSTALL.REPO.

### Code:

## Used when remacs is dependent on nightly
## Will print an error message telling people they need nightly rust
require_nightly=true

## Tools we need:
## Note that we respect the values of AUTOCONF etc, like autoreconf does.
progs="autoconf"

## Minimum versions we need:
autoconf_min=`sed -n 's/^ *AC_PREREQ(\([0-9\.]*\)).*/\1/p' configure.ac`


## $1 = program, eg "autoconf".
## Echo the version string, eg "2.59".
## FIXME does not handle things like "1.4a", but AFAIK those are
## all old versions, so it is OK to fail there.
## Also note that we do not handle micro versions.
get_version ()
{
    vers=`($1 --version) 2> /dev/null` && expr "$vers" : '[^
]* \([0-9][0-9.]*\).*'
}

## $1 = version string, eg "2.59"
## Echo the major version, eg "2".
major_version ()
{
    echo $1 | sed -e 's/\([0-9][0-9]*\)\..*/\1/'
}

## $1 = version string, eg "2.59"
## Echo the minor version, eg "59".
minor_version ()
{
    echo $1 | sed -e 's/[0-9][0-9]*\.\([0-9][0-9]*\).*/\1/'
}

## $1 = program
## $2 = minimum version.
## Return 0 if program is present with version >= minimum version.
## Return 1 if program is missing.
## Return 2 if program is present but too old.
## Return 3 for unexpected error (eg failed to parse version).
check_version ()
{
    ## Respect, e.g., $AUTOCONF if it is set, like autoreconf does.
    uprog0=`echo $1 | sed -e 's/-/_/g' -e 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'`

    eval uprog=\$${uprog0}

    if [ x"$uprog" = x ]; then
        uprog=$1
    else
        printf '%s' "(using $uprog0=$uprog) "
    fi

    command -v $uprog > /dev/null || return 1
    have_version=`get_version $uprog` || return 4

    have_maj=`major_version $have_version`
    need_maj=`major_version $2`

    [ x"$have_maj" != x ] && [ x"$need_maj" != x ] || return 3

    [ $have_maj -gt $need_maj ] && return 0
    [ $have_maj -lt $need_maj ] && return 2

    have_min=`minor_version $have_version`
    need_min=`minor_version $2`

    [ x"$have_min" != x ] && [ x"$need_min" != x ] || return 3

    [ $have_min -ge $need_min ] && return 0
    return 2
}

do_check=true
do_autoconf=false
do_git=false

for arg; do
    case $arg in
      --help)
	exec echo "$0: usage: $0 [--no-check] [target...]
  Targets are: all autoconf git";;
      --no-check)
        do_check=false;;
      all)
	do_autoconf=true
	test -r .git && do_git=true;;
      autoconf)
	do_autoconf=true;;
      git)
	do_git=true;;
      *)
	echo >&2 "$0: $arg: unknown argument"; exit 1;;
    esac
done

case $do_autoconf,$do_git in
  false,false)
    do_autoconf=true
    test -r .git && do_git=true;;
esac

echo "Validating Rust install ..."
command -v rustc >/dev/null 2>&1 || { echo >&2 "Remacs requires rust to be installed in order to build. Please install it via rustup: https://www.rustup.rs/; Aborting."; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo >&2 "Remacs requires cargo to be installed in order to build. Please install it via rustup: https://www.rustup.rs/; Aborting."; exit 1; }

if $require_nightly; then
    rustc --version | grep nightly || { echo >&2 "Remacs currently requires nightly Rust. If you do not have nightly Rust, you should install rustup at https://www.rustup.rs/, and run 'rustup install nightly' in the remacs directory."; exit 1; }
    echo "Your system has the required rust installation for building remacs."
fi

# Generate Autoconf-related files, if requested.

if $do_autoconf; then

  if $do_check; then

    echo 'Checking whether you have the necessary tools...
(Read INSTALL.REPO for more details on building Remacs)'

    missing=

    for prog in $progs; do

      sprog=`echo "$prog" | sed 's/-/_/g'`

      eval min=\$${sprog}_min

      printf '%s' "Checking for $prog (need at least version $min) ... "

      check_version $prog $min

      retval=$?

      case $retval in
          0) stat="ok" ;;
          1) stat="missing" ;;
          2) stat="too old" ;;
          4) stat="broken?" ;;
          *) stat="unable to check" ;;
      esac

      echo $stat

      if [ $retval -ne 0 ]; then
          missing="$missing $prog"
          eval ${sprog}_why=\""$stat"\"
      fi

    done


    if [ x"$missing" != x ]; then

      echo '
Building Remacs from the repository requires the following specialized programs:'

      for prog in $progs; do
          sprog=`echo "$prog" | sed 's/-/_/g'`

          eval min=\$${sprog}_min

          echo "$prog (minimum version $min)"
      done


      echo '
Your system seems to be missing the following tool(s):'

      for prog in $missing; do
          sprog=`echo "$prog" | sed 's/-/_/g'`

          eval why=\$${sprog}_why

          echo "$prog ($why)"
      done

      echo '
If you think you have the required tools, please add them to your PATH
and re-run this script.

Otherwise, please try installing them.
On systems using rpm and yum, try: "yum install PACKAGE"
On systems using dpkg and apt, try: "apt-get install PACKAGE"
Then re-run this script.

If you do not have permission to do this, or if the version provided
by your system is too old, it is normally straightforward to build
these packages from source.  You can find the sources at:

https://ftp.gnu.org/gnu/PACKAGE/

Download the package (make sure you get at least the minimum version
listed above), extract it using tar, then run configure, make,
make install.  Add the installation directory to your PATH and re-run
this script.

If you know that the required versions are in your PATH, but this
script has made an error, then you can simply re-run this script with
the --no-check option.

Please report any problems with this script to bug-gnu-emacs@gnu.org .'

      exit 1
    fi

    echo 'Your system has the required tools.'

  fi                            # do_check

  # Build aclocal.m4 here so that autoreconf need not use aclocal.
  # aclocal is part of Automake and might not be installed, and
  # autoreconf skips aclocal if aclocal.m4 is already supplied.
  ls m4/*.m4 | LC_ALL=C sort | sed 's,.*\.m4$,m4_include([&]),' \
    > aclocal.m4.tmp || exit
  if cmp -s aclocal.m4.tmp aclocal.m4; then
    rm -f aclocal.m4.tmp
  else
    echo "Building aclocal.m4 ..."
    mv aclocal.m4.tmp aclocal.m4
  fi || exit

  echo "Running 'autoreconf -fi -I m4' ..."

  ## Let autoreconf figure out what, if anything, needs doing.
  ## Use autoreconf's -f option in case autoreconf itself has changed.
  autoreconf -fi -I m4 || exit
fi


# True if the Git setup was OK before autogen.sh was run.

git_was_ok=true

if $do_git; then
    case `cp --help 2>/dev/null` in
      *--backup*--verbose*)
	cp_options='--backup=numbered --verbose';;
      *)
	cp_options='-f';;
    esac
fi


# Like 'git config NAME VALUE' but verbose on change and exiting on failure.
# Also, do not configure unless requested.

git_config ()
{
    $do_git || return

    name=$1
    value=$2

    ovalue=`git config --get "$name"` && test "$ovalue" = "$value" || {
       if $git_was_ok; then
	   echo 'Configuring local git repository...'
	   case $cp_options in
	       --backup=*)
		   config=$git_common_dir/config
		   cp $cp_options --force -- "$config" "$config" || exit;;
	   esac
       fi
       echo "git config $name '$value'"
       git config "$name" "$value" || exit
       git_was_ok=false
    }
}

echo "You can now run './configure'."

exit 0

### autogen.sh ends here
