#!/usr/bin/env bash                       # Shebang: Nutzt bash als Interpreter
# legt Labels in GitHub Repos an           # Skriptbeschreibung
# Basis: Excel Tabelle
#
# brew install gh + gh auth login          # Hinweis: gh-CLI installieren und authentifizieren
#
#
# Nutzung:
# chmod +x labeler.sh                      # Skript ausführbar machen
#   ./labeler.sh                           # Skript ausführen

set -euo pipefail #e bei fehler down,u verbot unges. var, o p-- für pipefehler

# Repo List - noch anlegen
REPOS=(                                    # Array für Repositories
  "https://github.com/HandlessReaper/Landing"   # Beispiel-Repo (auskommentiert)
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

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 1; }; } # Prüft, ob ein Kommando existiert
normalize_repo() {                         # Normalisiert Repo-URL zu owner/repo
  local line="$1"
  echo "$line" | sed -E 's#^git@github\.com:##; s#^https?://github\.com/##; s#\.git$##;' | xargs
}

ensure_label() {                           # Erstellt oder aktualisiert ein Label im Repo
  local repo="$1" name="$2" color="$3"
  if [[ -n "${DRY_RUN:-}" ]]; then
    echo "[DRY RUN] ensure $repo -> $name (#$color)"
    return 0
  fi
  if gh label list --repo "$repo" --limit 300 --search "$name" | awk '{print $1}' | grep -Fxq "$name"; then
    gh label edit "$name" --repo "$repo" --color "$color" >/dev/null 2>&1 || true
    echo "[OK] (exists) $repo -> $name (updated)"
  else
    gh label create "$name" --repo "$repo" --color "$color" >/dev/null
    echo "[OK] (created) $repo -> $name"
  fi
}

# Menü-Helfer
choose_one() {                             # Auswahlmenü für eine Kategorie
  local prompt="$1"; shift
  local -a options=( "$@" )
  echo
  echo "== $prompt =="
  local i=1
  for opt in "${options[@]}"; do
    local name="${opt%%|*}"
    echo "  $i) $name"
    ((i++))
  done
  echo "  0) Überspringen"
  local choice
  while true; do
    read -rp "Auswahl (Zahl): " choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo "Bitte Zahl eingeben."; continue; }
    if (( choice == 0 )); then
      echo ""
      return 0
    fi
    if (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[choice-1]}"
      return 0
    fi
    echo "Ungültige Auswahl."
  done
}

# Repo-Auswahl
choose_repo() {                            # Auswahlmenü für Repository
  echo "== Repository wählen =="
  local i=1
  for r in "${REPOS[@]}"; do
    echo "  $i) $r"
    ((i++))
  done                                       # Fehler: 'end' → 'done'
  echo "  0) Abbrechen"
  local choice
  while true; do
    read -rp "Auswahl (Zahl): " choice
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

# Main
require_cmd gh                             # Prüft, ob gh installiert ist
if ! gh auth status >/dev/null 2>&1; then  # Prüft, ob gh authentifiziert ist
  echo "Bitte vorher 'gh auth login' ausführen."
  exit 1
fi

echo "=== Interaktive Repo-Label-Vergabe ==="
repo="$(choose_repo)" || { echo "Abbruch."; exit 0; } # Repo auswählen
[[ -z "$repo" ]] && { echo "Abbruch."; exit 0; }     # Abbruch, falls leer
if ! [[ "$repo" =~ .+/.+ ]]; then                    # Prüft Repo-Format
  echo "Ungültiges Repo-Format: $repo"
  exit 1
fi
echo "-- Ausgewählt: $repo"

declare -a picked=()                                 # Array für gewählte Labels

# Pro Kategorie Auswahl treffen (leer = überspringen)
sel="$(choose_one 'Package Manager' "${PKG_MANAGER_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )
sel="$(choose_one 'Direct/Transitive' "${DIRECT_TRANSITIVE_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )
sel="$(choose_one 'Exposure' "${EXPOSURE_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )
sel="$(choose_one 'Runtime/Dev' "${USAGE_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )
sel="$(choose_one 'Maintained/Outdated' "${MAINTENANCE_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )
sel="$(choose_one 'Fix Status' "${FIX_STATUS_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )
sel="$(choose_one 'Priority' "${PRIORITY_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )
sel="$(choose_one 'Breaking Risk' "${BREAKING_LABELS[@]}")"; [[ -n "$sel" ]] && picked+=( "$sel" )

echo
echo "== Zusammenfassung =="
if ((${#picked[@]}==0)); then
  echo "Keine Labels gewählt. Ende."
  exit 0
fi
for p in "${picked[@]}"; do
  name="${p%%|*}"; color="${p##*|}"
  echo "  - $name (#$color)"
done

echo
read -rp "Jetzt auf GitHub anlegen/aktualisieren? [y/N]: " go
if [[ ! "$go" =~ ^[Yy]$ ]]; then
  echo "Abgebrochen."
  exit 0
fi

# Anlegen / Aktualisieren
for p in "${picked[@]}"; do
  name="${p%%|*}"
  color="${p##*|}"
  ensure_label "$repo" "$name" "$color"
done

echo "Fertig für $repo."