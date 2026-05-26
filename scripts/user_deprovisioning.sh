#!/bin/bash

# ==============================================================================
# Skriptname:       user_deprovisioning.sh
# Version:          1.1
# Zweck:            Interaktives Loeschen von Benutzern ueber Whiptail TUI
# Parameter:        Keine
# Rueckgabewert:    0 bei fehlerfreier Ausfuehrung, 1 bei Abbruechen
# Voraussetzungen:  Administrative Rechte, Paket whiptail
# Architektur:      Separation of Concerns, Modularisierung, Fail Fast Ansatz
# Author:           Tobias B
# ==============================================================================

set -euo pipefail

LOG_FILE="userlog.md"

# ==============================================================================
# Funktion: check_root
# Zweck:    Prueft Berechtigungen zur Ausfuehrung kritischer Systembefehle
# ==============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Kritischer Fehler: Das Skript erfordert administrative Rechte."
        exit 1
    fi
}

# ==============================================================================
# Funktion: check_dependencies
# Zweck:    Prueft das Vorhandensein zwingend benoetigter Pakete vor Ausfuehrung
# ==============================================================================
check_dependencies() {
    if ! command -v whiptail &> /dev/null; then
        echo "Kritischer Fehler: Das Paket whiptail ist nicht installiert."
        exit 1
    fi
}

# ==============================================================================
# Funktion: get_users_from_log
# Zweck:    Extrahiert alle erfolgreich angelegten Benutzernamen aus der Logdatei
# ==============================================================================
get_users_from_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Kritischer Fehler: Logdatei nicht gefunden."
        exit 1
    fi
    
    grep "Konto erfolgreich angelegt" "$LOG_FILE" | sed -n 's/.*Account \([^:]*\):.*/\1/p' | sort -u
}

# ==============================================================================
# Funktion: delete_user
# Zweck:    Loescht einen spezifischen Benutzer samt Heimatverzeichnis
# Parameter 1: Benutzername
# ==============================================================================
delete_user() {
    local username="$1"
    if id "$username" &>/dev/null; then
        userdel -r "$username"
        echo "Erfolg: Benutzer $username vollstaendig entfernt."
    else
        echo "Hinweis: Benutzer $username existiert nicht im System."
    fi
}

# ==============================================================================
# Funktion: interactive_deletion
# Zweck:    Steuert die Benutzereingabe und iteriert durch die Accountliste
# ==============================================================================
interactive_deletion() {
    local users
    
    # Einlesen der extrahierten Benutzerkonten in ein lokales Array
    mapfile -t users < <(get_users_from_log)

    if [[ ${#users[@]} -eq 0 ]]; then
        whiptail --title "Systemhinweis" --msgbox "Keine angelegten Benutzer in der Logdatei gefunden." 8 60
        exit 0
    fi

    local checklist_options=()
    for user in "${users[@]}"; do
        # Aufbau der Parameter-Struktur fuer whiptail: <Tag> <Item> <Status>
        checklist_options+=("$user" "Konto zur Loeschung markieren" "OFF")
    done

    local selected_users
    # Erfassung der Auswahl mittels File-Descriptor Swapping (3>&1 1>&2 2>&3)
    if ! selected_users=$(whiptail --title "Benutzer Deprovisionierung" \
        --checklist "Markieren Sie die zu loeschenden Benutzer (Leertaste):" \
        20 78 10 "${checklist_options[@]}" 3>&1 1>&2 2>&3); then
        echo "Information: Vorgang durch den Administrator abgebrochen."
        exit 0
    fi

    if [[ -z "$selected_users" ]]; then
        echo "Information: Es wurden keine Benutzerkonten zur Loeschung ausgewaehlt."
        exit 0
    fi

    # Entfernen der maskierenden Anfuehrungszeichen aus dem Return-String
    selected_users=$(echo "$selected_users" | tr -d '"')

    # Iteration ueber die selektierten Accounts
    for user in $selected_users; do
        delete_user "$user"
    done
    
    echo "System: Deprovisionierung ausgewaehlter Konten erfolgreich abgeschlossen."
}

# ==============================================================================
# Hauptprogramm
# ==============================================================================
main() {
    check_root
    check_dependencies
    interactive_deletion
}
main
