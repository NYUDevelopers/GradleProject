#!/bin/bash
# build-shell.sh - Start a nested shell with all the appropriate environment variables.

SCRIPT_NAME=${BASH_SOURCE[0]##*/}
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
UNAME=`uname`



setJavaHome

# TODO: We have located Java, so maybe we can generate more env vars with ./gradlew?

# Set GRADLE_HOME
export GRADLE_HOME=~/local/gradle
[ -x "$GRADLE_HOME/bin/gradle" ] || die "Couldn't find gradle in $GRADLE_HOME/bin"

# Use the daemon by default
# Actually, this is something that you're better off putting in your bash profile.
# export GRADLE_OPTS="-Dorg.gradle.daemon=true"

# Set CATALINA_HOME to a default value if it isn't already set.
setCatalinaHome

# Set the path
export PATH="$JAVA_HOME/bin:$GRADLE_HOME/bin:$CATALINA_HOME/bin:$SCRIPT_DIR/etc"

if $cygwin ; then
    [ -n "$CATALINA_HOME" ] && export CATALINA_HOME=`cygpath -w "${CATALINA_HOME}"`
    [ -n "$GRADLE_HOME" ] && export GRADLE_HOME=`cygpath -w "${GRADLE_HOME}"`
fi

export CHECKOUT_DIR=$SCRIPT_DIR

echo "JAVA_HOME=$JAVA_HOME"
echo "GRADLE_HOME=$GRADLE_HOME"
echo "CATALINA_HOME=$CATALINA_HOME"
echo "PATH=$PATH"
echo "CHECKOUT_DIR=$CHECKOUT_DIR"

# Set the prompt.

export PS1="\e[0;36m\h:\W \u\e[m> "

# Launch a nested shell, so we can simply exit to a 'clean' environment.
echo "*** You are now in a nested shell.  Type 'exit' to leave. ***"
exec $SHELL
