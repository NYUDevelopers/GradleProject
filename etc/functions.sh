#!/bin/bash
# Common shell functions and variables
ETC_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BASE_DIR=$( cd "${ETC_DIR}/.." && pwd )
BUILD_DIR=${BASE_DIR}/build
UNAME=`uname`

JDK_BASENAME='jdk1.7'
JDK_SUBDIR=""
# Use the maximum available, or set MAX_FD != -1 to use that value.
MAX_FD="maximum"
SHUTDOWN_WAIT=12
# OS specific support (must be 'true' or 'false').
cygwin=false
msys=false
darwin=false
case "${UNAME}" in
  CYGWIN* )
    cygwin=true
    ;;
  Darwin* )
    darwin=true
    ;;
  MINGW* )
    msys=true
    ;;
esac

function warn() {
    echo "${SCRIPT_NAME:-}: $*"
}

function die() {
    echo "${SCRIPT_NAME:-} ERROR $1"
    exit 1
}

function setEnv() {
        local ENV_FILE=${BASE_DIR}/build/shell/$1
        if [ ! -f ${ENV_FILE} ] ; then
            ${BASE_DIR}/gradlew genEnv || die "Unable to generate ${ENV_FILE}"
        fi
        [ -f ${ENV_FILE} ] || die "${ENV_FILE} not found.
*** PLEASE RUN 'gradle genEnv' OR  './gradlew genEnv' TO GENERATE ${ENV_FILE} ***"
        source ${ENV_FILE}
}

function findJavaHome() {
    local javadir
    local javaname
    local javahome
    if [ -z "${JAVA_HOME:-}" ] ; then
        for javadir in $@
        do
            javaname=`ls -1 ${javadir} | grep ${JDK_BASENAME} | tail -n 1`
            [ -z "${javaname}" ] && continue
            javahome="${javadir}/${javaname}${JDK_SUBDIR}"
            [ -z "${JAVA_HOME:-}" -a -d "${javahome}" ] && export JAVA_HOME="${javahome}"
        done
    fi
}

function setJavaHome() {
    # Attempt to set JAVA_HOME if it's not already set.
    if [ -z "${JAVA_HOME:-}" ] ; then
        if ${darwin} ; then
            [ -x "/usr/libexec/java_home" ] && export JAVA_HOME=`/usr/libexec/java_home`
            [ -z "${JAVA_HOME:-}" -a -d "/Library/Java/Home" ] && export JAVA_HOME="/Library/Java/Home"
            JDK_SUBDIR="/Contents/Home"  # OSX needs to use a sub directory.
            findJavaHome '/Library/Java/JavaVirtualMachines'
        elif ${cygwin} ; then
            findJavaHome '/opt' 'C:/PROGRA~1/Java'
        else
            findJavaHome '/opt' '/usr/java' '/usr/local/java'
            if [ -z "${JAVA_HOME:-}" ] ; then
                javaExecutable="`which javac`"
                [ -z "$javaExecutable" -o "`expr \"$javaExecutable\" : '\([^ ]*\)'`" = "no" ] && die "JAVA_HOME not set and cannot find javac to deduce location, please set JAVA_HOME."
                # readlink(1) is not available as standard on Solaris 10.
                readLink=`which readlink`
                [ `expr "$readLink" : '\([^ ]*\)'` = "no" ] && die "JAVA_HOME not set and readlink not available, please set JAVA_HOME."
                javaExecutable="`readlink -f \"$javaExecutable\"`"
                javaHome="`dirname \"$javaExecutable\"`"
                javaHome=`expr "$javaHome" : '\(.*\)/bin'`
                export JAVA_HOME="$javaHome"
            fi
        fi
    fi

    # For Cygwin, ensure paths are in UNIX format before anything is touched.
    if $cygwin ; then
        [ -n "$JAVA_HOME" ] && JAVA_HOME=`cygpath --unix "$JAVA_HOME"`
    fi

    [ -x "$JAVA_HOME/bin/java" ] || die "Couldn't find java in $JAVA_HOME/bin"
}

# Common Linux/Java issue - File descriptor limit can be too low.
function setFdLimit() {
    # Increase the maximum file descriptors if we can.
    if [ "$cygwin" = "false" -a "$darwin" = "false" ] ; then
        MAX_FD_LIMIT=`ulimit -H -n`
        if [ $? -eq 0 ] ; then
            if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ] ; then
                MAX_FD="$MAX_FD_LIMIT"
            fi
            ulimit -n ${MAX_FD}
            if [ $? -ne 0 ] ; then
                warn "Could not set maximum file descriptor limit: $MAX_FD"
            fi
        else
            warn "Could not query maximum file descriptor limit: $MAX_FD_LIMIT"
        fi
    fi
}

function setCatalinaHome() {
    [ ! -z "${JAVA_HOME:-}" ] || die "JAVA_HOME is not set!"

    if [ -z "${CATALINA_HOME:-}" ] ; then
        if [ -z "${TOMCAT_HOME:-}" ] ; then
            echo "WARNING: Niether CATALINA_HOME or TOMCAT_HOME are defined, using the default."
            export CATALINA_HOME=~/local/tomcat7
        else
            export CATALINA_HOME="${TOMCAT_HOME}"
        fi
    fi
}

function findPidJps() {
    local searchString=$1
    echo `jps -l | grep "${searchString}" | awk '{ print $1 }'`
}

function killProc() {
    if ${cygwin} ; then
        taskkill /PID $1
    else
        kill $1
    fi
}

function forceKill() {
    if ${cygwin} ; then
        taskkill /F /PID $1
    else
        kill -9 $1
    fi
}

function killAndWait() {
    local procId=$1
    local pidFile=$2

    # From http://blog.botha.us/sarel/?p=101
    echo -n "Waiting for ${procId} to stop ..."
    local kwait=${SHUTDOWN_WAIT}
    local count=0;
    until [ `jps | grep -c ${procId}` = '0' ] || [ ${count} -gt ${kwait} ]
    do
        echo -n ".";
        sleep 1
        let count=$count+1;
    done
    echo -n ". "

    if [ ${count} -gt ${kwait} ]; then
        echo "process ${procId} is still running after $SHUTDOWN_WAIT seconds, killing process"
        killProc ${procId}
        sleep 3

        # if it's still running use kill -9
        if [ `jps | grep -c ${procId} ` -gt '0' ]; then
            echo "process ${procId} is still running, forcibly killling..."
            forceKill ${procId}
            sleep 3
        fi
    fi

    if [ `jps | grep -c ${procId}` -gt '0' ]; then
        echo "process ${procId} is still running, I give up!"
    else
        # success, delete PID file
        echo "stopped ${procId}"
        if [ -f ${pidFile} ] ; then
            echo "removing ${pidFile}"
            rm ${pidFile}
        fi
    fi
}
