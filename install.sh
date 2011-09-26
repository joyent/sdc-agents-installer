#!/bin/bash

set -e
set -o xtrace

TMP=/var/tmp
AGENTS="$(ls *.tgz *.tar.gz || /bin/true)"
AGENTS_DIR=/opt/smartdc/agents
export PATH="$PATH:$AGENTS_DIR/bin"

export PATH=$AGENTS_DIR/modules/.npm/agents_core/active/package/local/bin:$PATH

SDC_CONFIG=/lib/sdc/config.sh

if [ -x "$SDC_CONFIG" ]; then
  source $SDC_CONFIG
  load_sdc_config
  load_sdc_sysinfo
fi

message() {
  echo "==> $*" >&2
}

npm-install() {
  WHAT=$1
  agents-npm --no-registry install "$WHAT"
}

rm-agent-dirs() {
  for dir in $(ls "$AGENTS_DIR" | grep -v "^db$"); do
    if [ "$dir" == "smf" ]; then
      rm $AGENTS_DIR/$dir/*
    else
      rm -fr $AGENTS_DIR/$dir
    fi
  done
}

cleanup-lime() {
  message "Upgrading agents from Lime-era release."
  TOREMOVE="$(agents-npm --no-registry ls installed | grep -v '^atropos@') atropos"
  for agent in "$TOREMOVE"; do
    log "Attempting to uninstall $agent"
    agents-npm uninstall $agent;
  done

  rm-agent-dirs
}

cleanup-agents() {
  message "Updating existing agents install."
  TOREMOVE="$(agents-npm --no-registry ls installed | awk '{ print $1 }')"
  for agent in "$TOREMOVE"; do
    if (echo "$agent" | grep '^atropos@'); then 
      continue
    fi

    agents-npm uninstall $agent;
  done

  rm-agent-dirs
}

cleanup-existing() {
  if [ -f "$AGENTS_DIR/bin/agents-npm" ] && agents-npm --no-registry ls atropos | grep 'installed'; then
    cleanup-lime
  elif [ -f "$AGENTS_DIR/bin/agents-npm" ]; then
    cleanup-agents
  fi
}

bootstrap() {
  # Run the bootstrap script
  if [ ! -f $AGENTS_DIR/bin/agents-npm ] || $AGENTS_DIR/bin/agents-npm --no-registry ls agents_core | awk '{ print $1 }' | grep 'installed'; then
    # Install the actual atropos agent
    tar -zxvf agents_core-*.tgz
    (cd agents_core && ./bootstrap/bootstrap.sh "$AGENTS_DIR")
  fi
}

install-agents() {
  # Install the agents locally
  for tarball in $AGENTS; do
    case "$tarball" in
      agents_core-*.tgz)
        ;;
      *)
        npm-install "./$tarball"
        ;;
    esac
  done
}

cleanup-existing
bootstrap
install-agents

exit 0