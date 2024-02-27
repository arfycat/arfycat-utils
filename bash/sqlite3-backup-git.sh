#!/usr/bin/false
{
  backup()
  {
    DB="$1" || return $?
    DIR="$2" || return $?
    FILE="$3" || return $?

    cd "$DIR" || return $?
    sqlite3 "$DB" .dump > "$DIR/$FILE" || return $?

    git checkout -q cron || return $?
    git pull -q || return $?
    git add "$DIR/$FILE" || return $?

    return 0
  }

  commit()
  {
    DIR="$1" || return $?

    cd "$DIR" || return $?
    if [[ $(git status -s --porcelain -uno | wc -l) -ne 0 ]]; then
      git gc || return $?
      git commit -m "$(date): $0" || return $?
      git push || return $?
    fi

    return 0
  }
}
