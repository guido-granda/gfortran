#!/usr/bin/env bash

function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

function logexec()
{
    echo \-\-\> "$@" >> $glcLogFile
    eval "$@" >> $glcLogFile 2>&1 
}

function logmessage()
{
    echo "$@"
    echo "$@" >>$glcLogFile 2>&1
}

# Define a log file.
glcLogFile=`pwd`"/Install.log"

# Get arugments.
TEMP=`getopt -o t --long toolPrefix::,asRoot::,rootPwd::,suMethod::,installLevel::,packageManager::,cores::,galacticusPrefix::,setCShell::,setBash::,ignoreFailures:: -- "$@"`
eval set -- "$TEMP"
cmdToolPrefix=
cmdAsRoot=
cmdRootPwd=
cmdInstallLevel=
cmdPackageManager=
cmdCores=
cmdSuMethod=
cmdGalacticusPrefix=
cmdSetCShell=
cmdSetBash=
cmdIgnoreFailures=
while true; do
    case "$1" in
	--asRoot ) cmdAsRoot="$2"; shift 2 ;;
	--cores ) cmdCores="$2"; shift 2 ;;
	--galacticusPrefix ) cmdGalacticusPrefix="$2"; shift 2 ;;
	--installLevel ) cmdInstallLevel="$2"; shift 2 ;;
	--packageManager ) cmdPackageManager="$2"; shift 2 ;;
	--rootPwd ) cmdRootPwd="$2"; shift 2 ;;
	--setCShell ) cmdSetCShell="$2"; shift 2 ;;
	--setBash ) cmdSetBash="$2"; shift 2 ;;
	--ignoreFailures ) cmdIgnoreFailures="$2"; shift 2 ;;
	--suMethod ) cmdSuMethod="$2"; shift 2 ;;
	--toolPrefix ) cmdToolPrefix="$2"; shift 2 ;;
	-- ) shift; break ;;
	* ) break ;;
    esac
done

# Validate arguments.
if [ ! -z ${cmdAsRoot} ]; then
    if [[ ${cmdAsRoot} != "no" && ${cmdAsRoot} != "yes" ]]; then
	logmessage "asRoot option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdSetCShell} ]; then
    if [[ ${cmdSetCShell} != "no" && ${cmdSetCShell} != "yes" ]]; then
	logmessage "setCShell option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdSetBash} ]; then
    if [[ ${cmdSetBash} != "no" && ${cmdSetBash} != "yes" ]]; then
	logmessage "setBash option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdIgnoreFailures} ]; then
    if [[ ${cmdIgnoreFailures} != "no" && ${cmdIgnoreFailures} != "yes" ]]; then
	logmessage "ignoreFailures option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdSuMethod} ]; then
    if [[ ${cmdSuMethod} != "su" && ${cmdSuMethod} != "sudo" ]]; then
	logmessage "suMethod option should be 'su' or 'sudo'"
	exit 1
    fi
fi
if [ ! -z ${cmdPackageManager} ]; then
    if [[ ${cmdPackageManager} != "no" && ${cmdPackageManager} != "yes" ]]; then
	logmessage "packageManager option should be 'yes' or 'no'"
	exit 1
    fi
fi
if [ ! -z ${cmdInstallLevel} ]; then
    if [[ ${cmdInstallLevel} != "binary" && ${cmdInstallLevel} != "minimal" && ${cmdInstallLevel} != "typical" && ${cmdInstallLevel} != "full" ]]; then
	logmessage "installLevel option should be 'binary', 'minimal', 'typical', or 'full'"
	exit 1
    fi
fi
if [ ! -z ${cmdCores} ]; then
    if [[ ! ${cmdCores} =~ ^[0-9]+$ ]]; then
	logmessage "cores option should be an integer"
	exit 1
    fi
fi

# Open the log file.
echo "Gfortran install log" > $glcLogFile

# Write some useful machine info to the log file if possible.
hash uname >& /dev/null
if [ $? -eq 0 ]; then
    uname -a >>$glcLogFile 2>&1
fi

# Create an install folder, and move into it.
mkdir -p galacticusInstallWork
cd galacticusInstallWork

# Do we want to install as root, or as a regular user?
if [[ $UID -eq 0 ]]; then
    echo "Script is being run as root."
    echo "Script is being run as root." >> $glcLogFile
    installAsRoot=1
    runningAsRoot=1
    # Set up a suitable install path.
    if [ -z ${cmdToolPrefix} ]; then
	toolInstallPath=/usr/local/galacticus
	read -p "Path to install tools to as root [$toolInstallPath]: " RESPONSE
	if [ -n "$RESPONSE" ]; then
            toolInstallPath=$RESPONSE
	fi
    else
 	toolInstallPath=${cmdToolPrefix}
    fi 	
else
    installAsRoot=-1
    runningAsRoot=0
fi
while [ $installAsRoot -eq -1 ]
do
    if [ -z ${cmdAsRoot} ]; then
	read -p "Install required libraries and Perl modules as root (requires root password)? [no/yes]: " RESPONSE
    else
	RESPONSE=${cmdAsRoot}
    fi
    if [ "$RESPONSE" = yes ] ; then
	# Installation will be done as root where possible.
        installAsRoot=1
	
	# Ask whether we should use "su" or "sudo" for root installs.
        suCommand="null"
        while [[ $suCommand == "null" ]]
        do
	    if [ -z ${cmdSuMethod} ]; then
		read -p "Use sudo or su for root installs:" suMethod
	    else
		suMethod=$cmdSuMethod
	    fi
            if [[ $suMethod == "su" ]]; then
		suCommand="su -c \""
		suClose="\""
		pName="root"
            elif [[ $suMethod == "sudo" ]]; then
		suCommand="sudo -E -S -- "
		suClose=""
		pName="sudo"
            fi
        done

        # Get the root password.
	if [ -z ${cmdRootPwd} ]; then
            read -s -p "Please enter the $pName password:" rootPassword
	else
	    rootPassword=$cmdRootPwd
	fi
	echo "$rootPassword" | eval $suCommand echo worked $suClose >& /dev/null
	echo
	if [ $? -ne 0 ] ; then
	    echo "$pName password was incorrect, exiting"
	    exit 1
	fi
	echo "Libraries and Perl modules will be installed as root"
	echo "Libraries and Perl modules will be installed as root" >> $glcLogFile

	# Set up a suitable install path.
	if [ -z ${cmdToolPrefix} ]; then
	    toolInstallPath=/usr/local/galacticus
            read -p "Path to install tools to as root [$toolInstallPath]: " RESPONSE
            if [ -n "$RESPONSE" ]; then
		toolInstallPath=$RESPONSE
            fi
	else
 	    toolInstallPath=${cmdToolPrefix}
	fi
    elif [ "$RESPONSE" = no ] ; then
	# Install as regular user.
        installAsRoot=0
	echo "Libraries and Perl modules will be installed as regular user"
	echo "Libraries and Perl modules will be installed as regular user" >> $glcLogFile

	# Set yp a suitable install path.
	if [ -z ${cmdToolPrefix} ]; then
            toolInstallPath=$HOME/tools_galacticus
            read -p "Path to install tools to [$toolInstallPath]: " RESPONSE
            if [ -n "$RESPONSE" ]; then
		toolInstallPath=$RESPONSE
            fi
	else
 	    toolInstallPath=${cmdToolPrefix}
 	fi
    else
	# Response invalid, try again.
	echo "Please enter 'yes' or 'no'"
    fi
done

# Export various environment variables with our install path prepended.
if [ -n "${PKG_CONFIG_PATH}" ]; then
    export PKG_CONFIG_PATH=$toolInstallPath/lib/pkgconfig:$PKG_CONFIG_PATH
else
    export PKG_CONFIG_PATH=$toolInstallPath/lib/pkgconfig
fi
if [ -n "${PATH}" ]; then
    export PATH=$toolInstallPath/bin:$PATH
else
    export PATH=$toolInstallPath/bin
fi
if [ -n "${LD_LIBRARY_PATH}" ]; then
    export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64:$LD_LIBRARY_PATH
else
    export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64
fi
if [ -n "${LD_RUN_PATH}" ]; then
    export LD_RUN_PATH=$toolInstallPath/lib:$toolInstallPath/lib64:$LD_RUN_PATH
else
    export LD_RUN_PATH=$toolInstallPath/lib:$toolInstallPath/lib64
fi
if [ -n "${LDFLAGS}" ]; then
    export LDFLAGS="-L$toolInstallPath/lib:$toolInstallPath/lib64:$LDFLAGS_PATH"
else
    export LDFLAGS="-L$toolInstallPath/lib:$toolInstallPath/lib64"
fi
if [ -n "${C_INCLUDE_PATH}" ]; then
    export C_INCLUDE_PATH=$toolInstallPath/include:$C_INCLUDE_PATH
else
    export C_INCLUDE_PATH=$toolInstallPath/include
fi
if [ -n "${PYTHONPATH}" ]; then
    export PYTHONPATH=$toolInstallPath/py-lib:$toolInstallPath/lib/python2.7/site-packages:$toolInstallPath/lib64/python2.7/site-packages:$PYTHONPATH
else
    export PYTHONPATH=$toolInstallPath/py-lib:$toolInstallPath/lib/python2.7/site-packages:$toolInstallPath/lib64/python2.7/site-packages
fi
if [ -n "${PERLLIB}" ]; then
    export PERLLIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl:$PERLLIB
else
    export PERLLIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl
fi
if [ -n "${PERL5LIB}" ]; then
    export PERL5LIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl:$PERL5LIB
else
    export PERL5LIB=$HOME/perl5/lib/perl5:$toolInstallPath/lib/perl5:$HOME/perl5/lib64/perl5:$toolInstallPath/lib64/perl5:$HOME/perl5/lib/perl5/site_perl:$toolInstallPath/lib/perl5/site_perl:$HOME/perl5/lib64/perl5/site_perl:$toolInstallPath/lib64/perl5/site_perl
fi

# Ensure that we use GNU compilers.
export CC=gcc
export CXX=g++
export FC=gfortran

# Binary, minimal, typical or full install?
installLevel=-2
while [ $installLevel -eq -2 ]
do
    if [ -z ${cmdInstallLevel} ]; then
	read -p "Binary, minimal, typical or full install?: " RESPONSE
    else
	RESPONSE=$cmdInstallLevel
    fi
    lcRESPONSE=${RESPONSE,,}
    if [ "$lcRESPONSE" = binary ] ; then
        installLevel=-1
	echo "Binary install only (plus anything required to run the binary)"
	echo "Binary install only (plus anything required to run the binary)" >> $glcLogFile
    elif [ "$lcRESPONSE" = minimal ] ; then
        installLevel=0
	echo "Minimal install only (just enough to compile and run Galacticus)"
	echo "Minimal install only (just enough to compile and run Galacticus)" >> $glcLogFile
    elif [ "$lcRESPONSE" = typical ] ; then
        installLevel=1
	echo "Typical install (compile, run, make plots etc.)"
	echo "Typical install (compile, run, make plots etc.)" >> $glcLogFile
    elif [ "$lcRESPONSE" = full ]; then
        installLevel=2
        echo "Full install"
        echo "Full install" >> $glcLogFile
    else
	echo "Please enter 'binary', 'minimal', 'typical' or 'full'"
    fi
done

# Use a package manager?
if [ $installAsRoot -eq 1 ]; then
    usePackageManager=-1
    while [ $usePackageManager -eq -1 ]
    do
	if [ -z $cmdPackageManager ]; then
	    read -p "Use package manager for install (if available)?: " RESPONSE
	else
	    RESPONSE=$cmdPackageManager
	fi
        if [ "$RESPONSE" = yes ] ; then
            usePackageManager=1
	    echo "Package manager will be used for installs if possible"
	    echo "Package manager will be used for installs if possible" >> $glcLogFile
	elif [ "$RESPONSE" = no ] ; then
            usePackageManager=0
	    echo "Package manager will not be used for installs"
	    echo "Package manager will not be used for installs" >> $glcLogFile
	else
	    echo "Please enter 'yes' or 'no'"
	fi
    done
else
    usePackageManager=0
fi

# Use multiple cores to compile.
coresAvailable=`grep -c ^processor /proc/cpuinfo`
coreCount=-1
while [ $coreCount -eq -1 ]
do
    if [ -z ${cmdCores} ]; then
	read -p "How many cores should I use when compiling? ($coresAvailable available): " RESPONSE
    else
	RESPONSE=$cmdCores
    fi
    if ! [[ "$RESPONSE" =~ ^[0-9]+$ ]] ; then
	    echo "Please enter an integer"
    else
	if [ "$RESPONSE" > 0 ] ; then
            coreCount=$RESPONSE
	    echo "Will use $coreCount cores for compiling"
	    echo "Will use $coreCount cores for compiling" >> $glcLogFile
	else
	    echo "Please enter a number greater than 0"
	fi
    fi
done

# Figure out which install options are available to us.
installViaYum=0
if [[ $installAsRoot -eq 1 && $usePackageManager -eq 1 ]]; then
    if hash yum >& /dev/null; then
	installViaYum=1
    fi
fi
installViaApt=0
if [[ $installAsRoot -eq 1 && $usePackageManager -eq 1 ]]; then
    if hash apt-get >& /dev/null; then
	installViaApt=1
        echo "$rootPassword" | eval $suCommand apt-get update $suClose
    fi
fi
installViaCPAN=0
if hash perl >& /dev/null; then
    perl -e "use CPAN" >& /dev/null
    if [ $? -eq 0 ]; then
	installViaCPAN=1
    fi
fi

# Specify a list of paths to search for Fortran modules and libraries.
moduleDirs="-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules -fintrinsic-modules-path /usr/local/finclude -fintrinsic-modules-path /usr/local/include/gfortran -fintrinsic-modules-path /usr/local/include -fintrinsic-modules-path /usr/lib/gfortran/modules -fintrinsic-modules-path /usr/include/gfortran -fintrinsic-modules-path /usr/include -fintrinsic-modules-path /usr/finclude -fintrinsic-modules-path /usr/lib64/gfortran/modules -L$toolInstallPath/lib -L$toolInstallPath/lib64"

# Specify a list of paths to search for library files.
libDirs="-L$toolInstallPath/lib -L$toolInstallPath/lib64"
#hdf5 libraries : guido

# Define packages.
iPackage=-1
# gcc (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
            iGCC=$iPackage
	iGCCVMin="4.0.0"
         package[$iPackage]="gcc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gcc"
      getVersion[$iPackage]="versionString=(\`gcc --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGCCVMin
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="gcc"
      aptInstall[$iPackage]="gcc"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

# g++ (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
            iGPP=$iPackage
	iGPPVMin="4.0.0"
         package[$iPackage]="g++"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash g++"
      getVersion[$iPackage]="versionString=(\`g++ --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGPPVMin
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="gcc-g++"
      aptInstall[$iPackage]="g++"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0

# GFortran (initial attempt - allow install via package manager only)
iPackage=$(expr $iPackage + 1)
        iFortran=$iPackage
    iFortranVMin="7.9.9"
         package[$iPackage]="gfortran"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gfortran"
      getVersion[$iPackage]="versionString=(\`gfortran --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]=$iFortranVMin
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="gcc-gfortran"
      aptInstall[$iPackage]="gfortran"
       sourceURL[$iPackage]="null-7"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]=""
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=0


# Apache Portable Runtime library (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iAPR=$iPackage
         package[$iPackage]="apr"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"main() {}\" > dummy.c; gcc dummy.c $libDirs -lapr-1"
      getVersion[$iPackage]="echo \"#include <apr-1/apr_version.h>\" > dummy.c; echo \"#include <stdio.h>\" >> dummy.c; echo \"main() {printf(\\\"%d.%d.%d\\\\n\\\",APR_MAJOR_VERSION,APR_MINOR_VERSION,APR_PATCH_VERSION);}\" >> dummy.c; gcc dummy.c $libDirs -lapr-1; ./a.out"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="apr-devel"
      aptInstall[$iPackage]="apr"
       sourceURL[$iPackage]="http://www-us.apache.org/dist//apr/apr-1.6.3.tar.bz2"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="test"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# Apache Portable Runtime utility (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
        iAPRutil=$iPackage
         package[$iPackage]="apr-util"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"main() {}\" > dummy.c; gcc dummy.c $libDirs -laprutil-1"
      getVersion[$iPackage]="echo \"#include <apr-1/apr_version.h>\" > dummy.c; echo \"#include <stdio.h>\" >> dummy.c; echo \"#include <apr-1/apu_version.h>\" >> dummy.c; echo \"main() {printf(\\\"%d.%d.%d\\\\n\\\",APU_MAJOR_VERSION,APU_MINOR_VERSION,APU_PATCH_VERSION);}\" >> dummy.c; gcc dummy.c $libDirs -laprutil-1; ./a.out"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="apr-util"
      aptInstall[$iPackage]="apr-util"
       sourceURL[$iPackage]="http://www-us.apache.org/dist//apr/apr-util-1.6.1.tar.bz2"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath --with-apr=$toolInstallPath"
        makeTest[$iPackage]="test"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1


# svn (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iSVN=$iPackage
         package[$iPackage]="svn"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash svn"
      getVersion[$iPackage]="svn --version --quiet"
      minVersion[$iPackage]="0.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="subversion"
      aptInstall[$iPackage]="subversion"
       sourceURL[$iPackage]="http://archive.apache.org/dist/subversion/subversion-1.9.7.tar.bz2"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# GMP (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iGMP=$iPackage
         package[$iPackage]="gmp"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <gmp.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lgmp"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <gmp.h>\" >> dummy.c; echo \"main() {printf(\\\"%d.%d.%d\\\\n\\\",__GNU_MP_VERSION,__GNU_MP_VERSION_MINOR,__GNU_MP_VERSION_PATCHLEVEL);}\" >> dummy.c; gcc dummy.c $libDirs -lgmp; ./a.out"
      minVersion[$iPackage]="4.3.2"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="gmp-devel"
      aptInstall[$iPackage]="libgmp3-dev"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# MPFR (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
           iMPFR=$iPackage
         package[$iPackage]="mpfr"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <mpfr.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lmpfr"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <mpfr.h>\" >> dummy.c; echo \"main() {printf(\\\"%s\\\\n\\\",MPFR_VERSION_STRING);}\" >> dummy.c; gcc dummy.c $libDirs -lmpfr; ./a.out"
      minVersion[$iPackage]="2.3.0999"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="mpfr-devel"
      aptInstall[$iPackage]="libmpfr-dev"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# MPC (will only be installed if we need to compile any of the GNU Compiler Collection)
iPackage=$(expr $iPackage + 1)
            iMPC=$iPackage
         package[$iPackage]="mpc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="echo \"#include <mpc.h>\" > dummy.c; echo \"main() {}\" >> dummy.c; gcc dummy.c $libDirs -lmpc"
      getVersion[$iPackage]="echo \"#include <stdio.h>\" > dummy.c; echo \"#include <mpc.h>\" >> dummy.c; echo \"main() {printf(\\\"%s\\\\n\\\",MPC_VERSION_STRING);}\" >> dummy.c; gcc dummy.c $libDirs -lmpc; ./a.out"
      minVersion[$iPackage]="1.0.0"
      maxVersion[$iPackage]="99.99.99"
      yumInstall[$iPackage]="libmpc-devel"
      aptInstall[$iPackage]="libmpc-dev"
       sourceURL[$iPackage]="null"
buildEnvironment[$iPackage]=""
   buildInOwnDir[$iPackage]=0
   configOptions[$iPackage]="--prefix=$toolInstallPath"
        makeTest[$iPackage]="check"
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# gcc (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
      iGCCsource=$iPackage
         package[$iPackage]="gcc"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gcc"
      getVersion[$iPackage]="versionString=(\`gcc --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGCCVMin
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="svn://gcc.gnu.org/svn/gcc/trunk"
buildEnvironment[$iPackage]="cd ../\$dirName; ./contrib/download_prerequisites; cd -"
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# g++ (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
      iGPPsource=$iPackage
         package[$iPackage]="g++"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash g++"
      getVersion[$iPackage]="versionString=(\`g++ --version\`); echo \${versionString[2]}"
      minVersion[$iPackage]=$iGPPVMin
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="svn://gcc.gnu.org/svn/gcc/trunk"
buildEnvironment[$iPackage]="cd ../\$dirName; ./contrib/download_prerequisites; cd -"
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# GFortran (second attempt - install from source)
iPackage=$(expr $iPackage + 1)
  iFortranSource=$iPackage
         package[$iPackage]="gfortran"
  packageAtLevel[$iPackage]=0
    testPresence[$iPackage]="hash gfortran"
      getVersion[$iPackage]="versionString=(\`gfortran --version\`); echo \${versionString[3]}"
      minVersion[$iPackage]=$iFortranVMin
      maxVersion[$iPackage]="9.9.9"
      yumInstall[$iPackage]="null"
      aptInstall[$iPackage]="null"
       sourceURL[$iPackage]="svn://gcc.gnu.org/svn/gcc/trunk"
buildEnvironment[$iPackage]="cd ../\$dirName; ./contrib/download_prerequisites; cd -"
   buildInOwnDir[$iPackage]=1
   configOptions[$iPackage]="--prefix=$toolInstallPath --enable-languages= --disable-multilib"
        makeTest[$iPackage]=""
     makeInstall[$iPackage]="install"
   parallelBuild[$iPackage]=1

# Install packages.
echo "Checking for required tools and libraries..." 
echo "Checking for required tools and libraries..." >> $glcLogFile

for (( i = 0 ; i < ${#package[@]} ; i++ ))
do
    # Test if this module should be installed at this level.
    if [ ${packageAtLevel[$i]} -le $installLevel ]; then
        # Check if package is installed.
	echo " Testing presence of ${package[$i]}" >> $glcLogFile
        installPackage=1
        eval ${testPresence[$i]} >>$glcLogFile 2>&1
        if [ $? -eq 0 ]; then
            # Check installed version.
	    echo "  ${package[$i]} is present - testing version" >> $glcLogFile
            version=`eval ${getVersion[$i]}` >>$glcLogFile 2>&1
	    echo "  Found version $version of ${package[$i]}" >> $glcLogFile
	    testLow=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
	    testHigh=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
	    if [[ "$testLow" != "test" && "$testHigh" != "test" ]]; then
	        installPackage=0
	    fi
	    echo "  Test results for ${package[$i]}: $testLow $testHigh" >> $glcLogFile
        fi
        # Check if installation is to be forced for this package.
	test $(contains "$@" "--force-${package[$i]}") == "y"
	if [ $? -eq 0 ]; then
	    installPackage=1
	fi
        # Install package if necessary.
        if [ $installPackage -eq 0 ]; then
	    echo ${package[$i]} - found
	    echo ${package[$i]} - found >> $glcLogFile
        else
	    echo ${package[$i]} - not found - will be installed
	    echo ${package[$i]} - not found - will be installed >> $glcLogFile
	    installDone=0
	    # Try installing via yum.
	    if [[ $installDone -eq 0 && $installViaYum -eq 1 && ${yumInstall[$i]} != "null" ]]; then
                # Check for presence in yum repos.
		for yumPackage in ${yumInstall[$i]}
		do
		    if [ $installDone -eq 0 ]; then
			versionString=(`echo "$rootPassword" | eval $suCommand yum -q -y list $yumPackage $suClose | tail -1`)
			if [ $? -eq 0 ]; then
			    version=${versionString[1]}
			    testLow=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
			    testHigh=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
			    if [[ "$testLow" != "test" && "$testHigh" != "test" ]]; then
				echo "   Installing via yum"
				echo "   Installing via yum" >> $glcLogFile
				echo "$rootPassword" | eval $suCommand yum -y install $yumPackage $suClose >>$glcLogFile 2>&1
				if ! eval ${testPresence[$i]} >& /dev/null; then
				    logmessage "   ...failed"
				    exit 1
				fi
				installDone=1
			    fi
			fi
		    fi
		done
            fi 
	    # Try installing via apt-get.
	    if [[ $installDone -eq 0 &&  $installViaApt -eq 1 && ${aptInstall[$i]} != "null" ]]; then
                # Check for presence in apt repos.
		aptPackages=(${aptInstall[$i]})
		for aptPackage in ${aptInstall[$i]}
		do
		    if [ $installDone -eq 0 ]; then
                        packageInfo=`apt-cache show $aptPackage`
			if [ $? -eq 0 ]; then
			    versionString=(`apt-cache show $aptPackage | sed -n '/Version/p' | sed -r s/"[0-9]+:"//`)
			    version=${versionString[1]}
			    testLow=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
			    testHigh=`echo "$version test:${minVersion[$i]}:${maxVersion[$i]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
			    if [[ "$testLow" != "test" && "$testHigh" != "test" ]]; then
				echo "   Installing via apt-get"
				echo "   Installing via apt-get" >> $glcLogFile
				echo "$rootPassword" | eval $suCommand apt-get -y install $aptPackage $suClose >>$glcLogFile 2>&1
				if ! eval ${testPresence[$i]} >& /dev/null; then
				    logmessage "   ...failed"
				    exit 1
				fi
				installDone=1
			    fi
			fi
		    fi
		done
	    fi
	    # Try installing via source.
	    if [[ $installDone -eq 0 && ${sourceURL[$i]} != "null" ]]; then
		if [[ ${sourceURL[$i]} =~ "fail:" ]]; then
		    abort="yes"
		    if [ -z ${cmdIgnoreFailures} ]; then
			abort=$cmdIgnoreFailures
		    fi
		    if [ "$abort" = yes ]; then
			logmessage "This installer can not currently install ${package[$i]} from source. Please install manually and then re-run this installer."
			exit 1
		    else
			logmessage "This installer can not currently install ${package[$i]} from source. Ignoring and continuing, but errors may occur."
		    fi
		else
		    logmessage "   Installing from source"
		    if [[ ${sourceURL[$i]} =~ "svn:" ]]; then
			logexec svn checkout \"${sourceURL[$i]}\"
			if [ $? -ne 0 ]; then
			    logmessage "Trying svn checkout again using http protocol instead"
			    baseName=`basename ${sourceURL[$i]}`
			    logexec rm -rf $baseName
			    logexec svn checkout "${sourceURL[$i]/svn:/http:}"
			fi
		    else
			logexec wget \"${sourceURL[$i]}\"
		    fi
		    if [ $? -ne 0 ]; then
			logmessage "Could not download ${package[$i]}"
			exit 1
		    fi
		    baseName=`basename ${sourceURL[$i]}`
		    if [[ ${sourceURL[$i]} =~ "svn:" ]]; then  
			dirName=$baseName
		    else
			unpack=`echo $baseName | sed -e s/.*\.bz2/j/ -e s/.*\.gz/z/ -e s/.*\.tgz/z/ -e s/.*\.tar//`
			logexec tar xvf$unpack $baseName
			if [ $? -ne 0 ]; then
			    logmessage "Could not unpack ${package[$i]}"
			    exit 1
			fi
			dirName=`tar tf$unpack $baseName | head -1 | sed s/"\/.*"//`
		    fi
		    if [ ${buildInOwnDir[$i]} -eq 1 ]; then
			mkdir -p $dirName-build
			cd $dirName-build
		    else
			cd $dirName
		    fi
		    # Hardwired magic.
     		    # Check for Python package.
		    if [ -z "${buildEnvironment[$i]}" ]; then
			isPython=0
			isPerl=0
			isCopy=0
		    else
			if [ "${buildEnvironment[$i]}" = "python" ]; then
			    isPython=1
			else
			    isPython=0
			fi
			if [ "${buildEnvironment[$i]}" = "perl" ]; then
			    isPerl=1
			else
			    isPerl=0
			fi
			if [ "${buildEnvironment[$i]}" = "copy" ]; then
			    isCopy=1
			else
			    isCopy=0
			fi
		    fi
		    if [ $isPython -eq 1 ]; then
		        # This is a Python package.
			if [ $installAsRoot -eq 1 ]; then
			    # Install Python package as root.
			    echo "$rootPassword" | $suCommand python setup.py install $suClose >>$glcLogFile 2>&1
			else
                            # Check that we have a virtual Python install
			    if [ ! -e $toolInstallPath/bin/python ]; then
				wget http://peak.telecommunity.com/dist/virtual-python.py >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to download virtual-python.py"
				    exit 1
				fi
                                # Check if there is a site-packages folder.
				virtualPythonOptions=" "
				pythonSitePackages=`python -c "import sys, os; py_version = 'python%s.%s' % (sys.version_info[0], sys.version_info[1]); print os.path.join(sys.prefix, 'lib', py_version,'site-packages')"`
				if [ ! -e $pythonSitePackages ]; then
				    virtualPythonOptions="$virtualPythonOptions --no-site-packages"
				    echo "No Python site-packages found - will run virtual-python.py with --no-site-packages options" >>$glcLogFile 2>&1
				fi
				python virtual-python.py --prefix $toolInstallPath $virtualPythonOptions >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to install virtual-python.py"
				    exit 1
				fi
				wget http://peak.telecommunity.com/dist/ez_setup.py >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to download ez_setup.py"
				    exit 1
				fi
				$toolInstallPath/bin/python ez_setup.py --prefix $toolInstallPath  >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to install ez_setup.py"
				    exit 1
				fi
			    fi
			    # Install Python package as regular user.
			    $toolInstallPath/bin/python setup.py install --prefix=$toolInstallPath >>$glcLogFile 2>&1
			fi
		        # Check that install succeeded.
			if [ $? -ne 0 ]; then
			    echo "Could not install ${package[$i]}"
			    echo "Could not install ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
		    elif [ $isCopy -eq 1 ]; then
		        # This is a package that we simply copy.
			if [ $installAsRoot -eq 1 ]; then
			    # Copy executable as root.
			    echo "$rootPassword" | $suCommand cp ${package[$i]} $toolInstallPath/bin/ $suClose >>$glcLogFile 2>&1
			else
			    # Copy executable as regular user.
			    cp ${package[$i]} $toolInstallPath/bin/ >>$glcLogFile 2>&1
			fi
		    elif [[ $i -eq $iBLAS ]]; then
			patch -p1 <<EOF
*** BLAS/make.inc       2011-04-19 12:08:00.000000000 -0700
--- BLAS1/make.inc      2011-12-01 07:24:51.671999364 -0800
***************
*** 16,24 ****
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran
! OPTS     = -O3
  DRVOPTS  = \$(OPTS)
! NOOPT    =
  LOADER   = gfortran
  LOADOPTS =
  #
--- 16,24 ----
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran
! OPTS     = -O3 -fPIC
  DRVOPTS  = \$(OPTS)
! NOOPT    = -fPIC
  LOADER   = gfortran
  LOADOPTS =
  #
EOF
                        if [ $? -ne 0 ]; then
			    logmesage "Failed to patch make.inc in blas"
			    exit 1
			fi
			patch -p1 <<EOF
*** BLAS/Makefile       2007-04-05 13:59:57.000000000 -0700
--- BLAS1/Makefile      2011-12-01 07:23:50.768481902 -0800
***************
*** 55,61 ****
  #
  #######################################################################
  
! all: \$(BLASLIB)
   
  #---------------------------------------------------------
  #  Comment out the next 6 definitions if you already have
--- 55,61 ----
  #
  #######################################################################
  
! all: \$(BLASLIB) libblas.so
   
  #---------------------------------------------------------
  #  Comment out the next 6 definitions if you already have
***************
*** 141,146 ****
--- 141,149 ----
        \$(ARCH) \$(ARCHFLAGS) \$@ \$(ALLOBJ)
        \$(RANLIB) \$@
  
+ libblas.so: \$(ALLOBJ)
+@X@cc -shared -Wl,-soname,libblas.so -o libblas.so \$(ALLOBJ)
+ 
  single: \$(SBLAS1) \$(ALLBLAS) \$(SBLAS2) \$(SBLAS3)
        \$(ARCH) \$(ARCHFLAGS) \$(BLASLIB) \$(SBLAS1) \$(ALLBLAS) \\
        \$(SBLAS2) \$(SBLAS3)
EOF
	                if [ $? -ne 0 ]; then
			    logmessage "Failed to patch Makefile in blas"
			    exit 1
			fi
			sed -i~ -r s/"@X@"/"\t"/g Makefile >>$glcLogFile 2>&1
			make libblas.so >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to make libblas.so"
			    exit 1
			fi
			mkdir -p $toolInstallPath/lib/ >>$glcLogFile 2>&1
			cp -f libblas.so $toolInstallPath/lib/ >>$glcLogFile 2>&1
		    elif [[ $i -eq $iLAPACK ]]; then
			if [ ! -e $toolInstallPath/lib/libblas.so ]; then
			    echo "Source install of lapack currently supported only if blas was also installed from source"
			    echo "Source install of lapack currently supported only if blas was also installed from source" >>$glcLogFile
			    exit 1
			fi
			cp make.inc.example make.inc >>$glcLogFile 2>&1
			patch -p1 <<EOF
*** lapack-3.4.0/make.inc       2011-12-01 07:47:04.696001005 -0800
--- lapack-3.4.0A/make.inc      2011-12-01 07:53:10.866744759 -0800
***************
*** 13,21 ****
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran 
! OPTS     = -O2
  DRVOPTS  = \$(OPTS)
! NOOPT    = -O0
  LOADER   = gfortran
  LOADOPTS =
  #
--- 13,21 ----
  #  desired load options for your machine.
  #
  FORTRAN  = gfortran 
! OPTS     = -O2 -fPIC
  DRVOPTS  = \$(OPTS)
! NOOPT    = -O0 -fPIC
  LOADER   = gfortran
  LOADOPTS =
  #
***************
*** 53,58 ****
  #  machine-specific, optimized BLAS library should be used whenever
  #  possible.)
  #
! BLASLIB      = ../../librefblas.a
! LAPACKLIB    = liblapack.a
! TMGLIB       = libtmglib.a
--- 53,58 ----
  #  machine-specific, optimized BLAS library should be used whenever
  #  possible.)
  #
! BLASLIB      = ../../librefblas.so
! LAPACKLIB    = liblapack.so
! TMGLIB       = libtmglib.so
EOF
                       if [ $? -ne 0 ]; then
			   logmessage "Failed to patch make.inc in lapack"
			   exit 1
		       fi
		       echo s\#BLASLIB\\s*=\\s*..\\/..\\/librefblas.so\#BLASLIB = $toolInstallPath\\/lib\\/libblas.so\# > rule.sed
		       sed -i~ -r -f rule.sed make.inc >>$glcLogFile 2>&1
		       if [ $? -ne 0 ]; then
			   logmessage "Failed to modify blas path in make.inc in lapack"
			   exit 1
		       fi
		       rm -f rule.sed
		       make all >>$glcLogFile 2>&1
		       if [ $? -ne 0 ]; then
			   logmessage "Failed to make lapack"
			   exit 1
		       fi
		       mkdir -p $toolInstallPath/lib/ >>$glcLogFile 2>&1
		       cp -f liblapack.so $toolInstallPath/lib/ >>$glcLogFile 2>&1
		       cp -f libtmglib.so $toolInstallPath/lib/ >>$glcLogFile 2>&1
		    elif [[ $i -eq $iHG ]]; then
			# Save a copy of the version file.
			cp mercurial/__version__.py mercurial/__version__.py.SAFE 
			# Make local version.
			make local >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    echo "Could not make ${package[$i]}"
			    echo "Could not make ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
		        # Install the package.
			if [ $installAsRoot -eq 1 ]; then
			    echo "$rootPassword" | eval $suCommand make install PREFIX=$toolInstallPath $suClose >>$glcLogFile 2>&1
			else
			    make install PREFIX=$toolInstallPath >>$glcLogFile 2>&1
			fi
			if [ $? -ne 0 ]; then
			    echo "Could not install ${package[$i]}"
			    echo "Could not install ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
			# Version file gets clobbered (due to bug in package).
			if [ ! -e $toolInstallPath/lib/python2.7/site-packages/mercurial/__version__.py ]; then
			    cp mercurial/__version__.py.SAFE $toolInstallPath/lib/python2.7/site-packages/mercurial/
			fi
		    else
                        # This is a regular (configure|make|make install) package.
                        # Test whether we have an m4 installed.
			hash m4 >& /dev/null
			if [ $? -ne 0 ]; then
			    echo "No m4 is present - will attempt to install prior to configuring"
			    echo "No m4 is present - will attempt to install prior to configuring" >>$glcLogFile
			    m4InstallDone=0
			    # Try installing via yum.
			    if [[ $m4InstallDone -eq 0 && $installViaYum -eq 1 ]]; then
				echo "$rootPassword" | $suCommand yum -y install m4 $suClose >>$glcLogFile 2>&1
				hash m4 >& /dev/null
				if [ $? -ne 0 ]; then
				    m4InstallDone=1
				fi
			    fi
			    # Try installing via apt-get.
			    if [[ $m4InstallDone -eq 0 && $installViaApt -eq 1 ]]; then
				echo "$rootPassword" | $suCommand apt-get -y install m4 $suClose >>$glcLogFile 2>&1
				hash m4 >& /dev/null
				if [ $? -ne 0 ]; then
				    m4InstallDone=1
				fi
			    fi
			    # Try installing from source.
			    if [[ $m4InstallDone -eq 0 ]]; then
				currentDir=`pwd`
				cd ..
				wget http://ftp.gnu.org/gnu/m4/m4-1.4.17.tar.gz >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to download m4 source"
				    exit 1
				fi
				tar xvfz m4-1.4.17.tar.gz >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to unpack m4 source"
				    exit 1
				fi
				cd m4-1.4.17
				./configure --prefix=$toolInstallPath >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to configure m4 source"
				    exit 1
				fi
				make >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to make m4"
				    exit 1
				fi
				make check >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to check m4"
				    exit 1
				fi
				make install >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed to install m4"
				    exit 1
				fi
				cd $currentDir
			    fi
			fi
		        # Configure the source.
			if [ $isPerl -eq 1 ]; then
			    if [ -e ../$dirName/Makefile.PL ]; then
				if [ $installAsRoot -eq 1 ]; then
				    perl ../$dirName/Makefile.PL >>$glcLogFile 2>&1
				else
				    perl ../$dirName/Makefile.PL PREFIX=$toolInstallPath >>$glcLogFile 2>&1
				fi
			    else
				echo "Can not locate Makefile.PL for ${package[$i]}"
				echo "Can not locate Makefile.PL for ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			    if [ $? -ne 0 ]; then
				echo "Could not build Makefile for ${package[$i]}"
				echo "Could not build Makefile for ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			else
			    # Hardwired magic.
			    # For HDF5 on older kernel versions we need to reduce optimization to prevent bug HDFFV-7829 
			    # from occuring during testing.
			    preConfig=" "
			    if [ $i -eq $iHDF5 ]; then
				version=`uname -r`
				testLow=`echo "$version test:3.4.999:9.9.9" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
				testHigh=`echo "$version test:3.4.999:9.9.9" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
				if [[ "$testLow" == "test" ]]; then
				    preConfig="env CFLAGS=-O0 "
				fi
			    fi
			    eval ${buildEnvironment[$i]}
			    if [ -e ../$dirName/configure ]; then
				logexec $preConfig ../$dirName/configure ${configOptions[$i]}
			    elif [ -e ../$dirName/config ]; then
				logexec $preConfig ../$dirName/config ${configOptions[$i]}
			    elif [[ ${configOptions[$i]} -ne "skip" ]]; then
				echo "Can not locate configure script for ${package[$i]}"
				echo "Can not locate configure script for ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			    if [ $? -ne 0 ]; then
				echo "Could not configure ${package[$i]}"
				echo "Could not configure ${package[$i]}" >>$glcLogFile
				exit 1
			    fi
			fi
		        # Make the package.
			makeOptions=" "
			if [ ${parallelBuild[$i]} -eq 1 ]; then
			    makeOptions=" -j$coreCount"
			fi
			logexec make $makeOptions
			if [ $? -ne 0 ]; then
			    echo "Could not make ${package[$i]}"
			    echo "Could not make ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
		        # Run any tests of the package.
			logexec make ${makeTest[$i]}
			if [ $? -ne 0 ]; then
			    logmessage "Testing ${package[$i]} failed"
			    exit 1
			fi
		        # Install the package.
			if [ $installAsRoot -eq 1 ]; then
			    echo "$rootPassword" | eval $suCommand make ${makeInstall[$i]} $suClose >>$glcLogFile 2>&1
			else
			    logexec make ${makeInstall[$i]}
			fi
			if [ $? -ne 0 ]; then
			    echo "Could not install ${package[$i]}"
			    echo "Could not install ${package[$i]}" >>$glcLogFile
			    exit 1
			fi
                        # Hardwired magic.
                        # For bzip2 we have to compile and install shared libraries manually......
			if [ $i -eq $iBZIP2 ]; then
 			    if [ $installAsRoot -eq 1 ]; then
				echo "$rootPassword" | eval $suCommand make clean $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 1"
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand make -f Makefile-libbz2_so $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 2"
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand cp libbz2.so* $toolInstallPath/lib/ $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 3"
				    exit 1
				fi
				echo "$rootPassword" | eval $suCommand chmod a+r $toolInstallPath/lib/libbz2.so* $suClose >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 4"
				    exit 1
				fi
			    else
				make clean >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 1"
				    exit 1
				fi
				make -f Makefile-libbz2_so >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 2"
				    exit 1
				fi
				cp libbz2.so* $toolInstallPath/lib/ >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 3"
				    exit 1
				fi
				chmod a+r $toolInstallPath/lib/libbz2.so*  >>$glcLogFile 2>&1
				if [ $? -ne 0 ]; then
				    logmessage "Failed building shared libraries for ${package[$i]} at stage 4"
				    exit 1
				fi
			    fi
			fi
		    fi
		fi
		cd ..
		# Re-export the PATH so that the newly installed executable gets picked up.
		export PATH=$PATH
		installDone=1
            fi
	    # No install methods worked - nothing else we can do (unless this was an
	    # initial attempt at installed a GNU compiler).
	    if [[ $installDone -eq 0 ]]; then
		echo "   no installation method exists"
		echo "   no installation method exists" >>$glcLogFile
		if [[ $i -eq $iFortran || $i -eq $iGCC || $i -eq $iGPP ]]; then
		    echo "      postponing"
		    echo "      postponing" >>$glcLogFile
		else
		    if [[ $i -eq $iMPFR || $i -eq $iMPC || $i -eq $iGMP ]]; then
			echo "      ignoring [will be installed with GCC]"
			echo "      ignoring [will be installed with GCC]" >>$glcLogFile
		    else
			exit 1
		    fi
		fi
            fi
 	    # Hardwired magic.
	    # If we installed SQLite, force SVN to use it.
	    if [ $i -eq $iZLIB ]; then
		configOptions[$iSVN]="${configOptions[$iSVN]} --with-zlib=$toolInstallPath"
	    fi
	    if [ $i -eq $iSQLite ]; then
		configOptions[$iSVN]="${configOptions[$iSVN]} --with-sqlite=$toolInstallPath"
	    fi
	    # If we installed APR, force SVN to use it.
	    if [ $i -eq $iAPR ]; then
		configOptions[$iSVN]="${configOptions[$iSVN]} --with-apr=$toolInstallPath"
	    fi
	    # If we installed APR utils, force SVN to use it.
	    if [ $i -eq $iAPRutil ]; then
		configOptions[$iSVN]="${configOptions[$iSVN]} --with-apr-util=$toolInstallPath"
	    fi
	    # If we installed SSL check that we have certificates.
	    if [ $i -eq $iSSL ]; then
		for dir in "/etc/ssl/certs"
		do
		    if [[ -e $dir/ca-bundle.crt && ! -e $toolInstallPath/ssl/certs/ca-bundle.crt ]]; then
			rm -rf $toolInstallPath/ssl/certs
			ln -sf $dir $toolInstallPath/ssl/certs
		    fi
		done
	    fi
	fi
        # Hardwired magic.        
	# If we installed (or already had) v1.13 or v1.14 of GSL then downgrade the version of FGSL that we want.
	if [ $i -eq $iGSL ]; then
	    gslVersion=`gsl-config --version`
	    if [ $gslVersion = "1.13" ]; then
		minVersion[$iFGSL]="0.9.2.9"
		maxVersion[$iFGSL]="0.9.2.1"
		sourceURL[$iFGSL]="http://www.lrz.de/services/software/mathematik/gsl/fortran/fgsl-0.9.2.tar.gz"
	    fi
	    if [ $gslVersion = "1.14" ]; then
		minVersion[$iFGSL]="0.9.2.9"
		maxVersion[$iFGSL]="0.9.3.1"
		sourceURL[$iFGSL]="http://www.lrz.de/services/software/mathematik/gsl/fortran/fgsl-0.9.3.tar.gz"
	    fi
	fi
        # Hardwired magic.        
        # Check if GCC/G++/Fortran are installed - delist MPFR, GMP and MPC if so.
	if [ $i -eq $iFortran ]; then
	    eval ${testPresence[$iFortran]} | test $(contains "$@" "--force-gfortran") == "y" >& /dev/null
	    gotFortran=$?
	    eval ${testPresence[$iGCC]} | test $(contains "$@" "--force-gcc") == "y" >& /dev/null
	    gotGCC=$?
	    eval ${testPresence[$iGPP]} | test $(contains "$@" "--force-g++") == "y" >& /dev/null
	    gotGPP=$?
	    if [[ $gotFortran -eq 0 && $gotGCC -eq 0 && $gotGPP -eq 0 ]]; then
                # Check installed versions.
		version=`eval ${getVersion[$iFortran]}`
		testLow=`echo "$version test:${minVersion[$iFortran]}:${maxVersion[$iFortran]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
		testHigh=`echo "$version test:${minVersion[$iFortran]}:${maxVersion[$iFortran]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
		if [[ "$testLow" = "test" || "$testHigh" = "test" ]]; then
		    gotFortran=1
		fi
		version=`eval ${getVersion[$iGCC]}`
		testLow=`echo "$version test:${minVersion[$iGCC]}:${maxVersion[$iGCC]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
		testHigh=`echo "$version test:${minVersion[$iGCC]}:${maxVersion[$iGCC]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
		if [[ "$testLow" = "test" || "$testHigh" = "test" ]]; then
		    gotGCC=1
		fi
		version=`eval ${getVersion[$iGPP]}`
		testLow=`echo "$version test:${minVersion[$iGPP]}:${maxVersion[$iGPP]}" | sed s/:/\\\\n/g | sort --version-sort | head -1 | cut -d " " -f 2`
		testHigh=`echo "$version test:${minVersion[$iGPP]}:${maxVersion[$iGPP]}" | sed s/:/\\\n/g | sort --version-sort | tail -1 | cut -d " " -f 2`
		if [[ "$testLow" = "test" || "$testHigh" = "test" ]]; then
		    gotGPP=1
		fi
	    fi
	    if [[ $gotFortran -eq 0 && $gotGCC -eq 0 && $gotGPP -eq 0 ]]; then
		# We have all GNU Compiler Collection components, so we don't need svn, GMP, MPFR, MPC, flex, or bison.
		packageAtLevel[$iSQLite]=100
		packageAtLevel[$iAPR]=100
		packageAtLevel[$iAPRutil]=100
		packageAtLevel[$iSVN]=100
		packageAtLevel[$iGMP]=100
		packageAtLevel[$iMPFR]=100
		packageAtLevel[$iMPC]=100
		packageAtLevel[$iFlex]=100
		packageAtLevel[$iBison]=100
	    else
		# We will need to install some GNU Compiler Collection components.
		# Select those components now.
		if [ $gotFortran -ne 0 ]; then
		    configOptions[$iFortranSource]=`echo ${configOptions[$iFortranSource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=fortran,"/ | sed -r s/", "/" "/`
		    configOptions[$iGCCsource]=`echo ${configOptions[$iGCCsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=fortran,"/ | sed -r s/", "/" "/`
		    configOptions[$iGPPsource]=`echo ${configOptions[$iGPPsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=fortran,"/ | sed -r s/", "/" "/`
		fi
		if [ $gotGCC -ne 0 ]; then
		    configOptions[$iFortranSource]=`echo ${configOptions[$iFortranSource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c,"/ | sed -r s/", "/" "/`
		    configOptions[$iGCCsource]=`echo ${configOptions[$iGCCsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c,"/ | sed -r s/", "/" "/`
		    configOptions[$iGPPsource]=`echo ${configOptions[$iGPPsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c,"/ | sed -r s/", "/" "/`
		fi
		if [ $gotGPP -ne 0 ]; then
		    configOptions[$iFortranSource]=`echo ${configOptions[$iFortranSource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c++,"/ | sed -r s/", "/" "/`
		    configOptions[$iGCCsource]=`echo ${configOptions[$iGCCsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c++,"/ | sed -r s/", "/" "/`
		    configOptions[$iGPPsource]=`echo ${configOptions[$iGPPsource]} | sed -r s/"\-\-enable\-languages="/"--enable-languages=c++,"/ | sed -r s/", "/" "/`
		fi
                # Hardwired magic.
                # On Ubuntu, we need to ensure that gcc-multilib is installed so that we can compile the gcc compilers.
		uname -v | grep -i ubuntu >& /dev/null
		if [ $? -eq 0 ]; then
		    if [ ! -e /usr/include/asm/errno.h ]; then
                        # gcc-multilib is not installed. If we don't have root access, we have a problem.
			if [ $installAsRoot -eq 1 ]; then
			    echo "$rootPassword" | eval $suCommand apt-get -y install gcc-multilib $suClose >>$glcLogFile 2>&1
			    if [ ! -e /usr/include/asm/errno.h ]; then
				logmessage "Failed to install gcc-multilib needed for compiling GNU Compiler Collection."
				exit 1
			    fi
			else
			    echo "I need to compile some of the GNU Compiler Collection."
			    echo "That requires that gcc-multilib be installed which requires root access."
			    echo "Please do: sudo apt-get install gcc-multilib"
			    echo "or ask your sysadmin to install it for you if necessary, then run this script again."
			    echo "I need to compile some of the GNU Compiler Collection." >>$glcLogFile
			    echo "That requires that gcc-multilib be installed which requires root access." >>$glcLogFile
			    echo "Please do: sudo apt-get install gcc-multilib" >>$glcLogFile
			    echo "or ask your sysadmin to install it for you if necessary, then run this script again." >>$glcLogFile
			    exit 1
			fi
		    fi
		fi
		
	    fi
	fi
        # Hardwired magic.
        # If we installed GFortran from source, don't allow HDF5 installs via yum or apt.
        # We need to build it from source to ensure we make the correct module version.
	if [ $i -eq $iFortran ]; then
	    if [ -e $toolInstallPath/bin/gfortran ]; then
		yumInstall[iHDF5]="null"
		aptInstall[iHDF5]="null"
	    fi
	fi
        # Hardwired magic.
        # If we installed GCC or G++ from source, don't allow other installs via yum or apt.
	if [ $i -eq $iFortran ]; then
	    if [[ -e $toolInstallPath/bin/gcc || -e $toolInstallPath/bin/g++ ]]; then
		yumInstall[iGSL]="null"
		aptInstall[iGSL]="null"
		yumInstall[iZLIB]="null"
		aptInstall[iZLIB]="null"
		yumInstall[iHDF5]="null"
		aptInstall[iHDF5]="null"
		yumInstall[iGNUPLOT]="null"
		aptInstall[iGNUPLOT]="null"
		yumInstall[iGRAPHVIZ]="null"
		aptInstall[iGRAPHVIZ]="null"
		yumInstall[iPYTHON]="null"
		aptInstall[iPYTHON]="null"
	    fi
	fi
    fi
done

# Set environment path for HDF5 if we installed our own copy.
if [ -e $toolInstallPath/lib/libhdf5.so ]; then
    export HDF5_PATH=$toolInstallPath
fi

# Specify the list of Perl modules and their requirements.
gotPerlLocalLibEnv=0
iPackage=-1
# CPAN
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="CPAN"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-CPAN"
    modulesApt[$iPackage]="perl-modules"
   interactive[$iPackage]=0

# Sub::Identify
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Sub::Identify"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Sub-Identify"
    modulesApt[$iPackage]="libsub-identify-perl"
   interactive[$iPackage]=0

# Text::Table
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Table"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Text-Table"
    modulesApt[$iPackage]="libtext-table-perl"
   interactive[$iPackage]=0

# Text::Template
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Template"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Text-Template"
    modulesApt[$iPackage]="libtext-template-perl"
   interactive[$iPackage]=0

# NestedMap
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="NestedMap"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]=""
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# Sub::Identify
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Sub::Identify"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Sub-Identify"
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# Regexp::Common
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Regexp::Common"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Regexp-Common"
    modulesApt[$iPackage]="libregexp-common-perl"
   interactive[$iPackage]=0

# Text::Wrap
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Wrap"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]=""
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# Sort::Topological
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Sort::Topological"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# LaTeX::Encode
#! <workaround>
#!  <description>Global symbols are not correctly imported with a modern Perl</description>
#!  <url>https://rt.cpan.org/Public/Bug/Display.html?id=87908</url>
#! </workaround>
iPackage=$(expr $iPackage + 1)
  iLaTeXEncode=$iPackage
       modules[$iPackage]="LaTeX::Encode"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
 modulesSource[$iPackage]="http://search.cpan.org/CPAN/authors/id/A/AN/ANDREWF/LaTeX-Encode-0.08.tar.gz"
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="liblatex-encode-perl"
   interactive[$iPackage]=0

# File::Find
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Find"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Which
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Which"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-File-Which"
    modulesApt[$iPackage]="libfile-which-perl"
   interactive[$iPackage]=0

# File::Temp
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Temp"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-File-Temp"
    modulesApt[$iPackage]="libfile-temp-perl"
   interactive[$iPackage]=0

# File::Copy
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Copy"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# IO::Compress::Bzip2
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="IO::Compress::Bzip2"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Compress-Bzip2"
    modulesApt[$iPackage]="libcompress-bzip2-perl"
   interactive[$iPackage]=0

# IO::Prompt
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="IO::Prompt"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-IO-prompt"
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# IO::Interactive
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="IO::Interactive"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]=""
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# Term::ReadKey
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Term::ReadKey"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-TermReadKey"
    modulesApt[$iPackage]="libterm-readkey-perl"
   interactive[$iPackage]=0

# Test::Inter
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Test::Inter"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Math::SigFigs
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Math::SigFigs"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Switch
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Switch"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=1
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# MIME::Lite
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="MIME::Lite"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-MIME-Lite"
    modulesApt[$iPackage]="libmime-lite-perl"
   interactive[$iPackage]=1

# Devel::CheckLib
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Devel::CheckLib"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::ShareDir
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::ShareDir"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Inline::C
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Inline::C"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-PDL"
    modulesApt[$iPackage]="pdl"
   interactive[$iPackage]=0

# Astro::Cosmology
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Astro::Cosmology"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=1
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Fatal
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Fatal"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-autodie"
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# XML::SAX
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::SAX"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-XML-SAX"
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# XML::Parser
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::Parser"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-XML-Parser"
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# XML::SAX::Expat
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::SAX::Expat"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-XML-SAX"
    modulesApt[$iPackage]=""
   interactive[$iPackage]=0

# XML::Simple
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::Simple"
modulesAtLevel[$iPackage]=-1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-XML-Simple"
    modulesApt[$iPackage]="libxml-simple-perl"
   interactive[$iPackage]=0

# GraphViz
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="GraphViz"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-GraphViz"
    modulesApt[$iPackage]="libgraphviz-perl"
   interactive[$iPackage]=0

# Image::Magick
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Image::Magick"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="ImageMagick-perl"
    modulesApt[$iPackage]="libimage-magick-perl"
   interactive[$iPackage]=0

# Carp
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Carp"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Cwd
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Cwd"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Data::Compare
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Data::Compare"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Data-Compare"
    modulesApt[$iPackage]="libdata-compare-perl"
   interactive[$iPackage]=0

# Data::Dumper
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Data::Dumper"
modulesAtLevel[$iPackage]=-1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Data-Dump"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# DateTime
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="DateTime"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-DateTime"
    modulesApt[$iPackage]="libdatetime-perl"
   interactive[$iPackage]=0

# Date::Format
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Date::Format"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libdatetime-perl"
   interactive[$iPackage]=0

# Date::Parse
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Date::Parse"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Exporter
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Exporter"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Fcntl
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Fcntl"
modulesAtLevel[$iPackage]=-1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Compare
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Compare"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Copy
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Copy"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Find
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Find"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# File::Slurp
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Slurp"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libfile-slurp-perl"
   interactive[$iPackage]=0

# File::Spec
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="File::Spec"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# threads
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="threads"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-threads"
    modulesApt[$iPackage]="libthreads-perl"
   interactive[$iPackage]=0

# Text::Balanced
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Text::Balanced"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Net::DBus
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Net::DBus"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Net-DBus"
    modulesApt[$iPackage]="libnet-dbus-perl"
   interactive[$iPackage]=0

# IO::Socket::SSL
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="IO::Socket::SSL"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-IO-Socket-SSL"
    modulesApt[$iPackage]="libio-socket-ssl-perl"
   interactive[$iPackage]=0

# Net::SMTP::SSL
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Net::SMTP::SSL"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Net-SMTP-SSL"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Scalar::Util
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Scalar::Util"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# Sys::CPU
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Sys::CPU"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Sys-CPU"
    modulesApt[$iPackage]="libsys-cpu-perl"
   interactive[$iPackage]=0

# PDL::LinearAlgebra
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::LinearAlgebra"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=1
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL::MatrixOps
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::MatrixOps"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL::NiceSlice
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::NiceSlice"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL::Ufunc
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="PDL::Ufunc"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# PDL::IO::HDF5
#iPackage=$(expr $iPackage + 1)
#       modules[$iPackage]="PDL::IO::HDF5"
#modulesAtLevel[$iPackage]=1
#  modulesForce[$iPackage]=0
#    modulesYum[$iPackage]="null"
#    modulesApt[$iPackage]="null"
#   interactive[$iPackage]=0

# POSIX
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="POSIX"
modulesAtLevel[$iPackage]=2
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# POSIX::strftime::GNU
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="POSIX::strftime::GNU"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# List::Uniq
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="List::Uniq"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# XML::Validator::Schema
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::Validator::Schema"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="null"
   interactive[$iPackage]=0

# XML::SAX
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="XML::SAX"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="null"
    modulesApt[$iPackage]="libxml-sax-perl"
   interactive[$iPackage]=0

# List::MoreUtils
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="List::MoreUtils"
modulesAtLevel[$iPackage]=0
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-List-MoreUtils"
    modulesApt[$iPackage]="liblist-moreutils-perl"
   interactive[$iPackage]=0

# Image::ExifTool
iPackage=$(expr $iPackage + 1)
       modules[$iPackage]="Image::ExifTool"
modulesAtLevel[$iPackage]=1
  modulesForce[$iPackage]=0
    modulesYum[$iPackage]="perl-Image-ExifTool"
    modulesApt[$iPackage]="libimage-exiftool-perl"
   interactive[$iPackage]=0

# Install required Perl modules.
echo "Checking for Perl modules..." 
echo "Checking for Perl modules..." >> $glcLogFile

for (( i = 0 ; i < ${#modules[@]} ; i++ ))
do
    # Test if this module should be installed at this level.
    if [ ${modulesAtLevel[$i]} -le $installLevel ]; then
        # Get the name of the module.
	module=${modules[$i]}
        # Test if the module is already present.
	echo "Testing for Perl module $module" >>$glcLogFile
	if [[ $module == "Inline::C" ]]; then
	    # Hardwired magic to test for Inline::C.
	    perl -e 'use Inline C=>q{void testpres(){printf("inline c present\n");}};testpres' >>$glcLogFile 2>&1
	else
	    perl -e "use $module" >>$glcLogFile 2>&1
	fi
	if [ $? -eq 0 ]; then
	    # Module already exists.
	    echo $module - found
	    echo $module - found >> $glcLogFile
	else
	    # Module must be installed.
	    echo $module - not found - will be installed
	    echo $module - not found - will be installed >> $glcLogFile
            installDone=0
	    # Try installing via yum.
	    if [[ $installDone -eq 0 && $installViaYum -eq 1 && ${modulesYum[$i]} != "null" ]]; then
                # Check for presence in yum repos.
                echo "$rootPassword" | eval $suCommand yum -y list ${modulesYum[$i]} $suClose >& /dev/null
                if [ $? -eq 0 ]; then
		    echo "   Installing via yum"
		    echo "   Installing via yum" >> $glcLogFile
		    echo "$rootPassword" | eval $suCommand yum -y install ${modulesYum[$i]} $suClose >>$glcLogFile 2>&1
		    perl -e "use $module" >& /dev/null
		    if [ $? -ne 0 ]; then
			logmessage "   ...failed"
			exit 1
		    fi
                    installDone=1
                fi
            fi 
	    # Try installing via apt.
	    if [[ $installDone -eq 0 &&  $installViaApt -eq 1 && ${modulesApt[$i]} != "null" ]]; then
		echo "   Installing via apt-get"
		echo "   Installing via apt-get" >> $glcLogFile
		echo "$rootPassword" | eval $suCommand apt-get -y install ${modulesApt[$i]} $suClose >>$glcLogFile 2>&1
		perl -e "use $module" >& /dev/null
		if [ $? -ne 0 ]; then
		    logmessage "   ...failed"
		    exit 1
		fi
                installDone=1
            fi
	    # Try installing from source.
	    if [[ $installDone -eq 0 && ${modulesSource[$i]} != "" ]]; then
		echo "   Installing from source"
		echo "   Installing from source" >>$glcLogFile
		wget "${modulesSource[$i]}" >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    echo "Could not download ${modules[$i]}"
		    echo "Could not download ${modules[$i]}" >>$glcLogFile
		    exit 1
		fi
		baseName=`basename ${modulesSource[$i]}`
		unpack=`echo $baseName | sed -e s/.*\.bz2/j/ -e s/.*\.gz/z/ -e s/.*\.tgz/z/ -e s/.*\.tar//`
		tar xvf$unpack $baseName >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    echo "Could not unpack ${modules[$i]}"
		    echo "Could not unpack ${modules[$i]}" >>$glcLogFile
		    exit 1
		fi
		dirName=`tar tf$unpack $baseName | head -1 | sed s/"\/.*"//`
		cd $dirName
# Hardwired magic.
#! <workaround>
#!  <description>Global symbols are not correctly imported with a modern Perl</description>
#!  <url>https://rt.cpan.org/Public/Bug/Display.html?id=87908</url>
#! </workaround>
# Apply a patch to LaTeX::Encode to fix symbol import issues.
if [ $i -eq $iLaTeXEncode ]; then
cd lib/LaTeX
sed -i~ s/"use LaTeX::Encode::EncodingTable;"/"#use LaTeX::Encode::EncodingTable;"/ Encode.pm
sed -i~ s/"use base qw(Exporter);"/"use base qw(Exporter);\nuse LaTeX::Encode::EncodingTable;"/ Encode.pm
cd -
fi
		# Configure the source.
		if [ -e ../$dirName/Makefile.PL ]; then
		    if [ $installAsRoot -eq 1 ]; then
			perl ../$dirName/Makefile.PL >>$glcLogFile 2>&1
		    else
			perl -Mlocal::lib ../$dirName/Makefile.PL >>$glcLogFile 2>&1
		    fi
		else
		    echo "Can not locate Makefile.PL for ${modules[$i]}"
		    echo "Can not locate Makefile.PL for ${modules[$i]}" >>$glcLogFile
		    exit 1
		fi
		if [ $? -ne 0 ]; then
		    echo "Could not build Makefile for ${modules[$i]}"
		    echo "Could not build Makefile for ${modules[$i]}" >>$glcLogFile
		    exit 1
		fi
		# Make the package.
		make -j >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    echo "Could not make ${modules[$i]}"
		    echo "Could not make ${modules[$i]}" >>$glcLogFile
		    exit 1
		fi
		# Run any tests of the package.
		make -j ${makeTest[$i]} >>$glcLogFile 2>&1
		if [ $? -ne 0 ]; then
		    logmessage "Testing ${modules[$i]} failed"
		    exit 1
		fi
		# Install the package.
		if [ $installAsRoot -eq 1 ]; then
		    echo "$rootPassword" | eval $suCommand make PATH=${PATH} install $suClose >>$glcLogFile 2>&1
		else
		    make install >>$glcLogFile 2>&1
		fi
		if [ $? -ne 0 ]; then
		    echo "Could not install ${modules[$i]}"
		    echo "Could not install ${modules[$i]}" >>$glcLogFile
		    exit 1
		fi
	    fi
	    # Try installing via CPAN.
	    if [[ $installDone -eq 0 &&  $installViaCPAN -eq 1 ]]; then
		logmessage "   Installing via CPAN"
		if [ ${modulesForce[$i]} -eq 1 ]; then
		    cpanInstall="force('install','${modules[$i]}')"
		else
		    cpanInstall="install ${modules[$i]}"
		fi
		if [ $installAsRoot -eq 1 ]; then
		    # Install as root.
                    export PERL_MM_USE_DEFAULT=1
		    if [ ${interactive[$i]} -eq 0 ]; then
			echo $suCommand perl -MCPAN -e "$cpanInstall" $suClose >>$glcLogFile 2>&1
			echo "$rootPassword" | eval $suCommand perl -MCPAN -e "$cpanInstall" $suClose >>$glcLogFile 2>&1
		    else
			echo $suCommand perl -MCPAN -e "$cpanInstall" $suClose >>$glcLogFile 2>&1
			echo "$rootPassword" | eval $suCommand perl -MCPAN -e "$cpanInstall" $suClose
		    fi
		else		    
                    # Check for local::lib.
		    logexec perl -e \"use local::lib\"
		    if [ $? -ne 0 ]; then
			wget http://search.cpan.org/CPAN/authors/id/H/HA/HAARG/local-lib-2.000015.tar.gz >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to download local-lib-2.000015.tar.gz"
			    exit
			fi
			tar xvfz local-lib-2.000015.tar.gz >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to unpack local-lib-2.000015.tar.gz"
			    exit
			fi
			cd local-lib-2.000015
			perl Makefile.PL --bootstrap >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to bootstrap local-lib-2.000015"
			    exit
			fi
			make >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to make local-lib-2.000015"
			    exit
			fi
			make test >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Tests of local-lib-2.000015 failed" >>$glcLogFile
			    exit
			fi
			make install >>$glcLogFile 2>&1
			if [ $? -ne 0 ]; then
			    logmessage "Failed to install local-lib-2.000015"			    
			    exit
			fi
		    fi
		    # Ensure that we're using the local::lib environment.
		    if [ $gotPerlLocalLibEnv -eq 0 ]; then
			eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
			gotPerlLocalLibEnv=1
		    fi
		    # Install as regular user.
		    export PERL_MM_USE_DEFAULT=1
		    if [ ${interactive[$i]} -eq 0 ]; then
			logexec perl -Mlocal::lib -MCPAN -e \"$cpanInstall\"
		    else
			echo perl -Mlocal::lib -MCPAN -e "$cpanInstall" >>$glcLogFile
			perl -Mlocal::lib -MCPAN -e "$cpanInstall"
		    fi
		fi
		# Check that the module was installed successfully.
		logexec perl -e \"use $module\" >>/dev/null 2>&1
		if [ $? -ne 0 ]; then
		    logmessage "   ...failed"
		    exit 1
		fi
                installDone=1
	    fi
	    # We were unable to install the module by any method.
	    if [ $installDone -eq 0 ]; then
		echo "no method exists to install this module"
		echo "no method exists to install this module" >> $glcLogFile
		exit 1;
	    fi
	fi
        # If we installed CPAN then make this an available method for future installs.
	if [[ $installViaCPAN -eq 0 && $module -eq "CPAN" ]]; then
	    installViaCPAN=1
	fi
    fi
    
done

# Retrieve Galacticus via Mercurial.
if [[ $runningAsRoot -eq 1 ]]; then
    echo "Script is running as root - if you want to install Galacticus itself as a regular user, just quit (Ctrl-C) now."
fi
if [ -z ${cmdGalacticusPrefix} ]; then
    galacticusInstallPath=$HOME/Galacticus/v0.9.4
    read -p "Path to install Galacticus to [$galacticusInstallPath]: " RESPONSE
    if [ -n "$RESPONSE" ]; then
	galacticusInstallPath=$RESPONSE
    fi
else
    galacticusInstallPath=$cmdGalacticusPrefix
fi
if [ ! -e $galacticusInstallPath ]; then
    mkdir -p `dirname $galacticusInstallPath`
    if [[ $installLevel -eq -1 ]]; then
	cd `dirname $galacticusInstallPath`
	wget http://users.obs.carnegiescience.edu/abenson/galacticus/versions/galacticus_v0.9.4.tar.bz2 2>&1
	tar xvfj galacticus_v0.9.4.tar.bz2 2>&1
	mv galacticus_v0.9.4 $galacticusInstallPath
	cd -
    else
	hg clone https://abensonca@bitbucket.org/abensonca/galacticus $galacticusInstallPath 2>&1
	if [ $? -ne 0 ]; then
	    logmessage "failed to download Galacticus"
	    exit 1
	fi
    fi
fi

# Add commands to .bashrc and/or .cshrc.
envSet=0
if [ -z ${cmdSetBash} ]; then
    read -p "Add a Galacticus environment alias to .bashrc? [no/yes]: " RESPONSE
else
    RESPONSE=$cmdSetBash
fi
if [ "$RESPONSE" = yes ] ; then
    envSet=1
    if [ -e $HOME/.bashrc ]; then
	awk 'BEGIN {inGLC=0} {if (index($0,"Alias to configure the environment to compile and run Galacticus v0.9.4") > 0) inGLC=1;if (inGLC == 0) print $0; if (inGLC == 1 && index($0,"'"'"'")) inGLC=0}' $HOME/.bashrc > $HOME/.bashrc.tmp
	mv -f $HOME/.bashrc.tmp $HOME/.bashrc
    fi
    echo "# Alias to configure the environment to compile and run Galacticus v0.9.4" >> $HOME/.bashrc
    echo "function galacticus094() {" >> $HOME/.bashrc
    echo " if [ -n \"\${LD_LIBRARY_PATH}\" ]; then" >> $HOME/.bashrc
    echo "  export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64:\$LD_LIBRARY_PATH" >> $HOME/.bashrc
    echo " else" >> $HOME/.bashrc
    echo "  export LD_LIBRARY_PATH=$toolInstallPath/lib:$toolInstallPath/lib64" >> $HOME/.bashrc
    echo " fi" >> $HOME/.bashrc
    echo " if [ -n \"\${PATH}\" ]; then" >> $HOME/.bashrc
    echo "  export PATH=$toolInstallPath/bin:\$PATH" >> $HOME/.bashrc
    echo " else" >> $HOME/.bashrc
    echo "  export PATH=$toolInstallPath/bin" >> $HOME/.bashrc
    echo " fi" >> $HOME/.bashrc
    echo " if [ -n \"\${PYTHONPATH}\" ]; then" >> $HOME/.bashrc
    echo "  export PYTHONPATH=$toolInstallPath/python:$toolInstallPath/py-lib:\$PYTHONPATH" >> $HOME/.bashrc
    echo " else" >> $HOME/.bashrc
    echo "  export PYTHONPATH=$toolInstallPath/python:$toolInstallPath/py-lib" >> $HOME/.bashrc
    echo " fi" >> $HOME/.bashrc
    if [ -e $HOME/perl5/lib/perl5/local/lib.pm ]; then
	echo " eval \$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)" >> $HOME/.bashrc
    fi
    echo " export GALACTICUS_FCFLAGS=\"-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules $libDirs\"" >> $HOME/.bashrc
    #echo " export GALACTICUS_FCFLAGS=\" $moduleDirs "
    echo " export GALACTICUS_CFLAGS=\"$libDirs -I$toolInstallPath/include\"" >> $HOME/.bashrc
    echo "}" >> $HOME/.bashrc
fi
if [ -z ${cmdSetCShell} ]; then
    read -p "Add a Galacticus environment alias to .cshrc? [no/yes]: " RESPONSE
else
    RESPONSE=$cmdSetCShell
fi
if [ "$RESPONSE" = yes ] ; then
    envSet=1
    if [ -e $HOME/.cshrc ]; then
	awk 'BEGIN {inGLC=0} {if (index($0,"Alias to configure the environment to compile and run Galacticus v0.9.4") > 0) inGLC=1;if (inGLC == 0) print $0; if (inGLC == 1 && index($0,"'"'"'")) inGLC=0}' $HOME/.cshrc > $HOME/.cshrc.tmp
	mv -f $HOME/.cshrc.tmp $HOME/.cshrc
    fi
    echo "# Alias to configure the environment to compile and run Galacticus v0.9.4" >> $HOME/.cshrc
    echo "alias galacticus094 'if ( \$?LD_LIBRARY_PATH ) then \\" >> $HOME/.cshrc
    echo " setenv LD_LIBRARY_PATH $toolInstallPath/lib:$toolInstallPath/lib64:\$LD_LIBRARY_PATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv LD_LIBRARY_PATH $toolInstallPath/lib:$toolInstallPath/lib64 \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    echo "if ( \$?PATH ) then \\" >> $HOME/.cshrc
    echo " setenv PATH $toolInstallPath/bin:\$PATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv PATH $toolInstallPath/bin \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    echo "if ( \$?PYTHONPATH ) then \\" >> $HOME/.cshrc
    echo " setenv PYTHONPATH $toolInstallPath/python:$toolInstallPath/py-lib:\$PYTHONPATH \\" >> $HOME/.cshrc
    echo "else \\" >> $HOME/.cshrc
    echo " setenv PYTHONPATH $toolInstallPath/python:$toolInstallPath/py-lib \\" >> $HOME/.cshrc
    echo "endif \\" >> $HOME/.cshrc
    if [ -e $HOME/perl5/lib/perl5/local/lib.pm ]; then
	echo "eval \`perl -I$HOME/perl5/lib/perl5 -Mlocal::lib\` \\" >> $HOME/.cshrc
    fi
    echo "setenv GALACTICUS_FCFLAGS \"-fintrinsic-modules-path $toolInstallPath/finclude -fintrinsic-modules-path $toolInstallPath/include -fintrinsic-modules-path $toolInstallPath/include/gfortran -fintrinsic-modules-path $toolInstallPath/lib/gfortran/modules $libDirs\"'" >> $HOME/.cshrc
    echo "setenv GALACTICUS_CFLAGS \"$libDirs -I$toolInstallPath/include\"'" >> $HOME/.cshrc
fi

# Determine if we want to install from source, or use the static binary.
cd $galacticusInstallPath
if [[ $installLevel -eq -1 ]]; then
    # Install the binary executable.
    logexec wget http://users.obs.carnegiescience.edu/abenson/galacticus/versions/Galacticus_v0.9.4_latest_x86_64.exe -O $galacticusInstallPath/Galacticus.exe 2>&1
    logexec chmod u+rx $galacticusInstallPath/Galacticus.exe
else
    
    # Hardwired magic.
    # Figure out which libstdc++ we should use. This is necessary because some
    # distributions (Ubuntu.....) don't find -lstdc++ when linking using gfortran.
    echo "main() {}" > dummy.c
    gcc dummy.c -lstdc++ >>$glcLogFile 2>&1
    if [ $? -eq 0 ]; then
	stdcppLibInfo=(`ldd a.out | grep libstdc++`)
	stdcppLib=${stdcppLibInfo[2]}
	if [ ! -e $toolInstallPath/lib/lidstdc++.so ]; then
	    if [ $installAsRoot -eq 1 ]; then
		echo "$rootPassword" | eval $suCommand ln -sf $stdcppLib $toolInstallPath/lib/lidstdc++.so >>$glcLogFile 2>&1
	    else
		ln -sf $stdcppLib $toolInstallPath/lib/libstdc++.so
	    fi
	fi
    fi
    
    # Build Galacticus.
    if [ ! -e Galacticus.exe ]; then
	export GALACTICUS_FCFLAGS=$moduleDirs
	make Galacticus.exe >>$glcLogFile 2>&1
	if [ $? -ne 0 ]; then
	    logmessage "failed to build Galacticus"
	    exit 1
	fi
    fi
fi

# Run a test case.
echo "Running a quick test of Galacticus - should take around 1 minute on a single core (less time if you have multiple cores)"
echo "Running a quick test of Galacticus - should take around 1 minute on a single core (less time if you have multiple cores)" >> $glcLogFile
./Galacticus.exe parameters/quickTest.xml >>$glcLogFile 2>&1
if [ $? -ne 0 ]; then
    logmessage "failed to run Galacticus"
    exit 1
fi
cd -

# Write a final message.
echo "Completed successfully"
echo "Completed successfully" >> $glcLogFile
echo
echo "You can delete the \"galacticusInstallWork\" folder if you want"
echo "You can delete the \"galacticusInstallWork\" folder if you want" >> $glcLogFile
echo
if [ $envSet -eq 1 ]; then
    echo "You should execute the command \"galacticus094\" before attempting to use Galacticus to configure all environment variables, library paths etc."
    echo "You should execute the command \"galacticus094\" before attempting to use Galacticus to configure all environment variables, library paths etc." >> $glcLogFile
else
    if [ $installAsRoot -eq 1 ]; then
	echo "If you installed Galacticus libraries and tools in a non-standard location you may need to set environment variables appropriately to find them. You will also need to set appropriate -fintrinsic-modules-path and -L options in the FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries."
	echo "If you installed Galacticus libraries and tools in a non-standard location you may need to set environment variables appropriately to find them. You will also need to set appropriate -fintrinsic-modules-path and -L options in the FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries." >> $glcLogFile
    else
	echo "You may need to set environment variables to permit libraries and tools installed to be found. You will also need to set appropriate -fintrinsic-modules-path and -L options in the FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries."
	echo "You may need to set environment variables to permit libraries and tools installed to be found. You will also need to set appropriate -fintrinsic-modules-path and -L options in the FCFLAGS variable of Galacticus' Makefile so that it know where to find installed modules and libraries." >> $glcLogFile
    fi
fi
exit 0
