#!/usr/bin/env bash                       
# legt Labels in GitHub Repos an           # Skriptbeschreibung
# Basis: Excel Tabelle
#
# brew install gh + gh auth login         
#
# Nutzung:
# chmod +x labeler.sh                      # Skript ausführbar machen
#   ./labeler.sh                           # Skript ausführen

set -euo pipefail #e bei fehler down,u verbot unges. var, o p-- für pipefehler

# Repo List - noch anlegen
REPOS=(                                    # Array für Repositories
  "https://github.com/HandlessReaper/Landing"   
)

# Basic ass farben
COLOR_GREEN="2da44e"                       # Grüner Farbcode
COLOR_BLUE="1f6feb"                        # Blauer Farbcode
COLOR_YELLOW="bf8700"                      # Gelber Farbcode
COLOR_ORANGE="d29922"                      # Oranger Farbcode
COLOR_RED="cf222e"                         # Roter Farbcode
COLOR_GREY="6e7781"                        # Grauer Farbcode
COLOR_PURPLE="8250df"                      # Lila Farbcode (Tippfehler korrigiert)
COLOR_CYAN="1b7c83"                        # Türkis Farbcode (Tippfehler korrigiert)

# Labels
PKG_MANAGER_LABELS=(                       # Labels für Paketmanager
  "pkg:npm|$COLOR_GREEN"
  "pkg:pypi|$COLOR_GREEN"
  "pkg:composer|$COLOR_GREEN"
  "pkg:maven|$COLOR_GREEN"
  "pkg:docker|$COLOR_GREEN"
  "pkg:github-actions|$COLOR_GREEN"
)

DIRECT_TRANSITIVE_LABELS=(                 # Labels für Abhängigkeitsart
  "dependency:direct|$COLOR_BLUE"
  "dependency:transitive|$COLOR_PURPLE"
)

EXPOSURE_LABELS=(                          # Labels für Sichtbarkeit
  "exposure:internal|$COLOR_RED"
  "exposure:external|$COLOR_BLUE"
)
 
USAGE_LABELS=(                             # Labels für Nutzungsart
  "usage:runtime|$COLOR_GREEN"
  "usage:dev|$COLOR_GREY"
)

MAINTENANCE_LABELS=(                       # Labels für Wartungsstatus
  "status:maintained|$COLOR_GREEN"
  "status:outdated|$COLOR_YELLOW"
  "status:archived|$COLOR_GREY"
)

FIX_STATUS_LABELS=(                        # Labels für Fix-Status
  "fix:need-fix|$COLOR_ORANGE"
  "fix:no-fix-needed|$COLOR_GREEN"
  "fix:no-fix-available|$COLOR_PURPLE"
)

PRIORITY_LABELS=(                          # Labels für Priorität
  "priority:high|$COLOR_RED"
  "priority:low|$COLOR_GREY"
)

BREAKING_LABELS=(                          # Labels für Breaking Changes
  "breaking:none|$COLOR_GREEN"
  "breaking:possible|$COLOR_YELLOW"
)

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 1; }; }

normalize_repo() {
  local line="$1"
  echo "$line" \
    | sed -E 's#^git@github\.com:##; s#^https?://github\.com/##; s#\.git$##;' \
    | xargs
}

ensure_label() {
  local repo="$1" name="$2" color="$3"
  if [[ -n "${DRY_RUN:-}" ]]; then
    echo "  [DRY RUN] ensure $repo -> $name (#$color)"
    return 0
  fi
  if gh label list --repo "$repo" --limit 300 --search "$name" | awk '{print $1}' | grep -Fxq "$name"; then
    gh label edit "$name" --repo "$repo" --color "$color" >/dev/null 2>&1 || true
    echo "  [OK] (update) $name"
  else
    gh label create "$name" --repo "$repo" --color "$color" >/dev/null
    echo "  [OK] (create) $name"
  fi
}

choose_from_list() {
  # usage: choose_from_list "Titel" "${array[@]}"
  local title="$1"; shift
  local -a options=( "$@" )
  echo
  echo "== $title =="
  local i=1
  for opt in "${options[@]}"; do
    local name="${opt%%|*}"
    printf "  %2d) %s\n" "$i" "$name"
    ((i++))
  done
  echo "   0) Überspringen"
  local choice
  while true; do
    read -rp "Auswahl [0-${#options[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo "Bitte Zahl eingeben."; continue; }
    if (( choice == 0 )); then
      echo ""  # leere Rückgabe = Skip
      return 0
    fi
    if (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[choice-1]}"
      return 0
    fi
    echo "Ungültige Auswahl."
  done
}

choose_repo() {
  echo
  echo "== Repository wählen =="
  local i=1
  for r in "${REPOS[@]}"; do
    printf "  %2d) %s\n" "$i" "$r"
    ((i++))
  done
  echo "   0) Abbrechen"
  local choice
  while true; do
    read -rp "Auswahl [0-${#REPOS[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo "Bitte Zahl eingeben."; continue; }
    if (( choice == 0 )); then
      echo ""
      return 1
    fi
    if (( choice >= 1 && choice <= ${#REPOS[@]} )); then
      local sel="${REPOS[choice-1]}"
      echo "$(normalize_repo "$sel")"
      return 0
    fi
    echo "Ungültige Auswahl."
  done
}

label_flow_for_repo() {
  local repo="$1"
  echo "-- Ausgewählt: $repo"

  local picked=()
  local sel

  sel="$(choose_from_list 'Package Manager' "${PKG_MANAGER_LABELS[@]}")";         [[ -n "$sel" ]] && picked+=( "$sel" )
  sel="$(choose_from_list 'Direct/Transitive' "${DIRECT_TRANSITIVE_LABELS[@]}")";  [[ -n "$sel" ]] && picked+=( "$sel" )
  sel="$(choose_from_list 'Exposure' "${EXPOSURE_LABELS[@]}")";                    [[ -n "$sel" ]] && picked+=( "$sel" )
  sel="$(choose_from_list 'Runtime/Dev' "${USAGE_LABELS[@]}")";                    [[ -n "$sel" ]] && picked+=( "$sel" )
  sel="$(choose_from_list 'Maintained/Outdated' "${MAINTENANCE_LABELS[@]}")";      [[ -n "$sel" ]] && picked+=( "$sel" )
  sel="$(choose_from_list 'Fix Status' "${FIX_STATUS_LABELS[@]}")";                [[ -n "$sel" ]] && picked+=( "$sel" )
  sel="$(choose_from_list 'Priority' "${PRIORITY_LABELS[@]}")";                    [[ -n "$sel" ]] && picked+=( "$sel" )
  sel="$(choose_from_list 'Breaking Risk' "${BREAKING_LABELS[@]}")";               [[ -n "$sel" ]] && picked+=( "$sel" )

  echo
  echo "== Zusammenfassung =="
  if ((${#picked[@]}==0)); then
    echo "Keine Labels gewählt."
  else
    for p in "${picked[@]}"; do
      local name="${p%%|*}" color="${p##*|}"
      echo "  - $name (#$color)"
    done
  fi

  echo
  read -rp "Jetzt auf GitHub anlegen/aktualisieren? [y/N]: " go
  if [[ "$go" =~ ^[Yy]$ ]]; then
    for p in "${picked[@]}"; do
      local name="${p%%|*}" color="${p##*|}"
      ensure_label "$repo" "$name" "$color"
    done
    echo "Fertig für $repo."
  else
    echo "Abgebrochen für $repo."
  fi
}

# ===== Main Loop =====
require_cmd gh
if ! gh auth status >/dev/null 2>&1; then
  echo "Bitte vorher 'gh auth login' ausführen."
  exit 1
fi

echo "=== Interaktive Repo-Label-Vergabe ==="

while true; do
  repo="$(choose_repo)" || { echo "Abbruch."; exit 0; }
  [[ -z "$repo" ]] && { echo "Abbruch."; exit 0; }
  if ! [[ "$repo" =~ .+/.+ ]]; then
    echo "Ungültiges Repo-Format: $repo"
    continue
  fi

  label_flow_for_repo "$repo"

  echo
  read -rp "Noch ein Repo bearbeiten? [y/N]: " again
  [[ "$again" =~ ^[Yy]$ ]] || { echo "Bye."; break; }
done
