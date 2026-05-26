#!/bin/bash

# ==============================================================================
# Skriptname:       user_manager.sh
# Version:          1.0
# Zweck:            TUI zur zentralen Steuerung der Benutzerverwaltung
# Parameter:        Keine
# Rueckgabewert:    0 bei fehlerfreier Ausfuehrung, 1 bei Abbruechen
# Voraussetzungen:  Administrative Rechte, ausführbare Unterskripte
# Architektur:      Modularisierung, Endlosschleife
# Author:           Tobias B
# ==============================================================================

set -euo pipefail

PROVISION_SCRIPT="./user_provisioning.sh"
DEPROVISION_SCRIPT="./user_deprovisioning.sh"

# ==============================================================================
# Funktion: check_root
# Zweck:    Prueft Berechtigungen zur Ausfuehrung
# ==============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Kritischer Fehler: Das Skript erfordert administrative Rechte."
        exit 1
    fi
}

# ==============================================================================
# Funktion: check_scripts
# Zweck:    Prueft Existenz und Ausfuehrbarkeit der Module
# ==============================================================================
check_scripts() {
    if [[ ! -x "$PROVISION_SCRIPT" ]]; then
        echo "Kritischer Fehler: $PROVISION_SCRIPT fehlt oder ist nicht ausfuehrbar."
        exit 1
    fi
    if [[ ! -x "$DEPROVISION_SCRIPT" ]]; then
        echo "Kritischer Fehler: $DEPROVISION_SCRIPT fehlt oder ist nicht ausfuehrbar."
        exit 1
    fi
}

# ==============================================================================
# Funktion: show_menu
# Zweck:    Gibt die grafische Oberflaeche im Terminal aus
# ==============================================================================
show_menu() {
    clear
    echo "=========================================="
    echo "       Benutzerverwaltung Manager         "
    echo "=========================================="
    echo "1 Benutzer automatisiert anlegen"
    echo "2 Benutzer interaktiv loeschen"
    echo "3 Programm beenden"
    echo "=========================================="
}

# ==============================================================================
# Funktion: handle_choice
# Zweck:    Verarbeitet die Benutzereingabe
# ==============================================================================
handle_choice() {
    local choice="$1"
    case "$choice" in
        1)
            echo "Starte Provisionierung..."
            "$PROVISION_SCRIPT"
            read -r -p "ENTER druecken fuer Rueckkehr zum Menue" _
            ;;
        2)
            echo "Starte Deprovisionierung..."
            "$DEPROVISION_SCRIPT"
            read -r -p "ENTER druecken fuer Rueckkehr zum Menue" _
            ;;
        3)
            echo "Programm erfolgreich beendet."
            exit 0
            ;;
        *)
            echo "Fehler: Ungueltige Eingabe."
            sleep 2
            ;;
    esac
}

# ==============================================================================
# Hauptprogramm
# ==============================================================================
main() {
    check_root
    check_scripts

    while true; do
        show_menu
        read -r -p "Auswahl: " user_input
        handle_choice "$user_input"
    done
}

main
