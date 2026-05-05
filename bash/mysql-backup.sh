#!/usr/bin/env bash
{
  set -euo pipefail
  umask 077

  DIR="/cache/mysql-$(hostname -s)"
  cd "$DIR"

  for DB in $(mysql -B --disable-column-names -e "show databases;"); do
    if [[ $DB == "information_schema" || $DB == "performance_schema" ]]; then
      continue
    fi

    DBDIR="$DIR/$DB"
    if [[ ! -d "$DBDIR" ]]; then
      mkdir "$DBDIR"
    fi

    chown :mysql "$DBDIR"
    chmod 770 "$DBDIR"

    mysqldump --skip-comments "--tab=$DBDIR" "$DB"
  done

  git pull -q
  git add .
  if [[ $(git status -s --porcelain -uno | wc -l) -ne 0 ]]; then
    git commit -m "$(date): $0"
    git push
  fi

  exit 0
}