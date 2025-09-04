#!/usr/bin/env bash
# interactive-topics-edit-v2.sh
# Repo wählen -> pro Kategorie aktuelle Topics sehen -> gezielt ADD / DELETE / REPLACE
# Mit Alias→Kanonisch-Mapping (z. B. node/nodejs ⇒ npm). Es werden nur die gewählten Änderungen ausgeführt.
# Voraussetzungen: gh installiert + gh auth login
# Windows-Tipp: In VS Code auf LF-Zeilenenden & UTF-8 (ohne BOM) achten.

set -euo pipefail

# ===== Repos (URLs oder owner/repo) =====
REPOS=(
  "https://github.com/HandlessReaper/Landing"
  # weitere Repos …
)

# ===== Kategorien (KANONISCHE Topics) =====
PKG_MANAGER_TOPICS=(npm pypi composer maven docker github-actions)
DEPENDENCY_TOPICS=(dependency-direct dependency-transitive)
EXPOSURE_TOPICS=(exposure-internal exposure-external)
USAGE_TOPICS=(usage-runtime usage-dev)
MAINTENANCE_TOPICS=(status-maintained status-outdated status-archived)
FIX_STATUS_TOPICS=(fix-need-fix fix-no-fix-needed fix-no-fix-available)
PRIORITY_TOPICS=(priority-high priority-low)
BREAKING_TOPICS=(breaking-none breaking-possible)
TEAM_TOPICS=(ext b2b bcas cloud dwh erp ffas fin ful inf legal man oma pas pic prd qa sec smi)

# Liste aller Kategorien [Titel;ArrayName]
CATEGORIES=(
  "Package Manager;PKG_MANAGER_TOPICS"
  "Direct/Transitive;DEPENDENCY_TOPICS"
  "Exposure;EXPOSURE_TOPICS"
  "Runtime/Dev;USAGE_TOPICS"
  "Maintained/Outdated;MAINTENANCE_TOPICS"
  "Fix Status;FIX_STATUS_TOPICS"
  "Priority;PRIORITY_TOPICS"
  "Breaking Risk;BREAKING_TOPICS"
  "Team;TEAM_TOPICS"
)

# ===== Alias → Kanonisch =====
# alles lowercase; nur a-z0-9- (wir sanitizen vor Lookup)
declare -A TOPIC_ALIAS=(
  # pkg
  [npm]=npm [node]=npm [nodejs]=npm
  [pypi]=pypi [pip]=pypi [python]=pypi
  [composer]=composer [php]=composer
  [maven]=maven [java]=maven
  [docker]=docker [container]=docker [containers]=docker
  [github-actions]=github-actions [actions]=github-actions [gha]=github-actions
  # dependency
  [dependency-direct]=dependency-direct [direct]=dependency-direct [direct-dependency]=dependency-direct
  [dependency-transitive]=dependency-transitive [transitive]=dependency-transitive
  # exposure
  [exposure-internal]=exposure-internal [internal]=exposure-internal
  [exposure-external]=exposure-external [external]=exposure-external
  # usage
  [usage-runtime]=usage-runtime [runtime]=usage-runtime
  [usage-dev]=usage-dev [dev]=usage-dev [development]=usage-dev
  # status
  [status-maintained]=status-maintained [maintained]=status-maintained
  [status-outdated]=status-outdated [outdated]=status-outdated
  [status-archived]=status-archived [archived]=status-archived
  # fix
  [fix-need-fix]=fix-need-fix [need-fix]=fix-need-fix
  [fix-no-fix-needed]=fix-no-fix-needed [no-fix-needed]=fix-no-fix-needed
  [fix-no-fix-available]=fix-no-fix-available [no-fix-available]=fix-no-fix-available
  # priority
  [priority-high]=priority-high [high-priority]=priority-high
  [priority-low]=priority-low [low-priority]=priority-low
  # breaking
  [breaking-none]=breaking-none [no-breaking]=breaking-none
  [breaking-possible]=breaking-possible [breaking]=breaking-possible

  # --- Teams: ausgeschriebene Namen/Varia → Kürzel ---
  # ext
  [ext]=ext [external]=ext [extern]=ext [public]=ext
  # b2b
  [b2b]=b2b [business-to-business]=b2b
  # bcas (falls abteilungsname schon etabliert; belasse Mapping 1:1)
  [bcas]=bcas
  # cloud
  [cloud]=cloud [cloud-platform]=cloud [cloud-team]=cloud
  # dwh
  [dwh]=dwh [data-warehouse]=dwh [datawarehouse]=dwh [data-warehousing]=dwh
  # erp
  [erp]=erp [enterprise-resource-planning]=erp
  # ffas
  [ffas]=ffas
  # fin
  [fin]=fin [finance]=fin [financial]=fin
  # ful
  [ful]=ful [fulfillment]=ful [fulfilment]=ful
  # inf
  [inf]=inf [infrastructure]=inf [infra]=inf [platform]=inf
  # legal
  [legal]=legal [legal-team]=legal [legals]=legal [recht]=legal
  # man
  [man]=man [management]=man [it-management]=man
  # oma  (Order Management – verschieden geschrieben)
  [oma]=oma
  [order-management]=oma [order--management]=oma
  [ordermanagement]=oma [order_management]=oma
  [order mgmt]=oma [order-mgmt]=oma [order-management-team]=oma
  # pas
  [pas]=pas
  # pic
  [pic]=pic
  # prd
  [prd]=prd [product]=prd [product-team]=prd [produkt]=prd
  # qa
  [qa]=qa [quality-assurance]=qa [quality]=qa [quality-assurance-team]=qa [test]=qa [testing]=qa
  # sec
  [sec]=sec [security]=sec [security-team]=sec [infosec]=sec [appsec]=sec [cybersecurity]=sec
  # smi
  [smi]=smi
)

# ===== Helpers =====
require_cmd(){ command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1" >&2; exit 1; }; }
normalize_repo(){ echo "$1" | sed -E 's#^git@github\.com:##; s#^https?://github\.com/##; s#\.git$##;' | xargs; }

sanitize_topic() {
  local t="${1,,}"        # lowercase
  t="${t// /-}"           # spaces -> -
  t="$(echo "$t" | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//')"
  echo "$t"
}

canonicalize_topic() {
  local t; t="$(sanitize_topic "$1")"
  if [[ -n "${TOPIC_ALIAS[$t]+x}" ]]; then
    echo "${TOPIC_ALIAS[$t]}"
  else
    echo "$t"
  fi
}

choose_one_from_array() {
  local title="$1"; shift
  local -a options=( "$@" )
  echo "" >&2; echo "== $title ==" >&2
  local i=1; for opt in "${options[@]}"; do printf "  %2d) %s\n" "$i" "$opt" >&2; ((i++)); done
  echo "   0) Zurück" >&2
  local choice
  while true; do
    read -rp "Auswahl [0-${#options[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo "Bitte Zahl eingeben." >&2; continue; }
    (( choice==0 )) && { echo ""; return 1; }
    if (( choice>=1 && choice<=${#options[@]} )); then
      echo "${options[choice-1]}"
      return 0
    fi
    echo "Ungültige Auswahl." >&2
  done
}

choose_repo() {
  echo "" >&2; echo "== Repository wählen ==" >&2
  local i=1; for r in "${REPOS[@]}"; do printf "  %2d) %s\n" "$i" "$r" >&2; ((i++)); done
  echo "   0) Abbrechen" >&2
  local choice
  while true; do
    read -rp "Auswahl [0-${#REPOS[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { echo "Bitte Zahl eingeben." >&2; continue; }
    (( choice==0 )) && return 1
    if (( choice>=1 && choice<=${#REPOS[@]} )); then
      echo "$(normalize_repo "${REPOS[choice-1]}")"
      return 0
    fi
    echo "Ungültige Auswahl." >&2
  done
}

# State aus GitHub lesen
# Füllt zwei Arrays:
#   EXISTING_TOPICS_RAW   – die echten Topics im Repo
#   EXISTING_TOPICS_CANON – kanonische Entsprechungen (Alias aufgelöst)
fetch_existing_topics() {
  local repo="$1"
  mapfile -t EXISTING_TOPICS_RAW < <(gh repo view "$repo" --json repositoryTopics --jq '.repositoryTopics[].topic.name' 2>/dev/null || true)
  EXISTING_TOPICS_CANON=()
  local x
  for x in "${EXISTING_TOPICS_RAW[@]:-}"; do
    EXISTING_TOPICS_CANON+=( "$(canonicalize_topic "$x")" )
  done
}

# Additiv hinzufügen (kanonisch)
add_topic(){
  local repo="$1" topic_raw="$2"
  local topic; topic="$(canonicalize_topic "$topic_raw")"
  [[ -z "$topic" ]] && return 0
  if [[ -n "${DRY_RUN:-}" ]]; then echo "  [DRY RUN] add-topic $repo -> $topic"; return 0; fi
  if gh repo edit "$repo" --add-topic "$topic" >/dev/null 2>&1; then
    echo "  [OK] topic added: $topic"
  else
    echo "  [WARN] topic add skipped: $topic"
  fi
}

# Gezielt löschen (per RAW-Name, damit exakt das entfernt wird, was drauf ist)
delete_topic(){
  local repo="$1" topic_raw="$2"
  [[ -z "$topic_raw" ]] && return 0
  if [[ -n "${DRY_RUN:-}" ]]; then echo "  [DRY RUN] delete-topic $repo -> $topic_raw"; return 0; fi
  if gh repo edit "$repo" --delete-topic "$topic_raw" >/dev/null 2>&1; then
    echo "  [OK] topic deleted: $topic_raw"
  else
    echo "  [WARN] topic delete skipped: $topic_raw"
  fi
}

# Aktuellen Stand pro Kategorie anzeigen:
# – Katalog (kanonisch)
# – In dieser Kategorie gesetzte Topics (RAW-Namen), deren kanonische Form im Katalog enthalten ist
print_category_state() {
  local title="$1" array_name="$2"
  eval "local -a catalog=(\"\${${array_name}[@]}\")"
  local -a in_cat_raw=()
  local idx raw canon
  for idx in "${!EXISTING_TOPICS_CANON[@]}"; do
    canon="${EXISTING_TOPICS_CANON[$idx]}"
    raw="${EXISTING_TOPICS_RAW[$idx]}"
    for c in "${catalog[@]}"; do
      if [[ "$canon" == "$c" ]]; then
        in_cat_raw+=( "$raw" )
        break
      fi
    done
  done

  echo
  echo "-- Kategorie: $title --"
  echo "Katalog: ${catalog[*]}"
  if ((${#in_cat_raw[@]})); then
    echo "Aktuell (RAW, passend zur Kategorie): ${in_cat_raw[*]}"
  else
    echo "Aktuell (RAW): (keins in dieser Kategorie)"
  fi
}

# Interaktiv je Kategorie: ADD / DELETE / REPLACE
edit_category() {
  local repo="$1" title="$2" array_name="$3"
  eval "local -a catalog=(\"\${${array_name}[@]}\")"

  while true; do
    print_category_state "$title" "$array_name"
    echo "Aktion wählen:"
    echo "  1) Aus Katalog HINZUFÜGEN (kanonisch)"
    echo "  2) Vorhandenes (RAW, in dieser Kategorie) LÖSCHEN"
    echo "  3) REPLACE: alle in dieser Kategorie löschen (RAW) + EINEN aus Katalog setzen"
    echo "  0) Fertig / Zurück"
    local act; read -rp "Auswahl: " act
    case "$act" in
      1)
        local pick
        if ! pick="$(choose_one_from_array "$title – hinzufügen" "${catalog[@]}")"; then continue; fi
        [[ -n "$pick" ]] && add_topic "$repo" "$pick"
        ;;
      2)
        fetch_existing_topics "$repo"
        local -a current_in_cat=()
        local idx
        for idx in "${!EXISTING_TOPICS_CANON[@]}"; do
          local canon="${EXISTING_TOPICS_CANON[$idx]}"
          local raw="${EXISTING_TOPICS_RAW[$idx]}"
          if printf "%s\n" "${catalog[@]}" | grep -Fxq "$canon"; then
            current_in_cat+=( "$raw" )
          fi
        done
        if ((${#current_in_cat[@]}==0)); then
          echo "  [INFO] In dieser Kategorie gibt es aktuell nichts zu löschen."
          continue
        fi
        local del
        if ! del="$(choose_one_from_array "$title – löschen (RAW)" "${current_in_cat[@]}")"; then continue; fi
        [[ -n "$del" ]] && delete_topic "$repo" "$del"
        ;;
      3)
        fetch_existing_topics "$repo"
        local -a to_del=()
        local idx
        for idx in "${!EXISTING_TOPICS_CANON[@]}"; do
          local canon="${EXISTING_TOPICS_CANON[$idx]}"
          local raw="${EXISTING_TOPICS_RAW[$idx]}"
          if printf "%s\n" "${catalog[@]}" | grep -Fxq "$canon"; then
            to_del+=( "$raw" )
          fi
        done
        if ((${#to_del[@]})); then
          echo "  [WARN] Es werden gelöscht (nur Kategorie, RAW): ${to_del[*]}"
          read -rp "Sicher? [y/N]: " ok
          if [[ "$ok" =~ ^[Yy]$ ]]; then
            for t in "${to_del[@]}"; do delete_topic "$repo" "$t"; done
          else
            continue
          fi
        fi
        local pick2
        if ! pick2="$(choose_one_from_array "$title – setzen (kanonisch)" "${catalog[@]}")"; then continue; fi
        [[ -n "$pick2" ]] && add_topic "$repo" "$pick2"
        ;;
      0) break ;;
      *) echo "Ungültige Auswahl." ;;
    esac
    # Nach jeder Aktion Bestand aktualisieren
    fetch_existing_topics "$repo"
  done
}

# ===== Main =====
require_cmd gh
if ! gh auth status >/dev/null 2>&1; then
  echo "Bitte vorher 'gh auth login' ausführen." >&2
  exit 1
fi

echo "=== Interaktive Repo-Topics: ansehen + hinzufügen/löschen/ersetzen (kategorienbezogen) ==="
repo="$(choose_repo)" || { echo "Abbruch."; exit 0; }
[[ -z "$repo" ]] && { echo "Abbruch."; exit 0; }
if ! [[ "$repo" =~ .+/.+ ]]; then
  echo "Ungültiges Repo-Format: $repo" >&2
  exit 1
fi

echo "-- Ausgewählt: $repo"
echo "Vorhandene Topics (gesamt):"
fetch_existing_topics "$repo"
printf "  %s\n" "${EXISTING_TOPICS_RAW[@]:-}"

# Pro Kategorie bearbeiten
for cat in "${CATEGORIES[@]}"; do
  IFS=';' read -r title arrname <<< "$cat"
  edit_category "$repo" "$title" "$arrname"
done

echo
echo "== Finale Topics (gesamt) =="
fetch_existing_topics "$repo"
printf "  %s\n" "${EXISTING_TOPICS_RAW[@]:-}"
echo "Fertig."
