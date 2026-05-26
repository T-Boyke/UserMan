#!/bin/bash

# ==============================================================================
# Skriptname:       whiptail_manager.sh
# Version:          1.3
# Zweck:            Erweiterte grafische TUI zur Steuerung der Benutzerverwaltung
# Parameter:        Keine
# Rueckgabewert:    0 bei fehlerfreier Ausfuehrung, 1 bei Abbruechen
# Voraussetzungen:  Administrative Rechte, whiptail, ausfuehrbare Unterskripte
# Architektur:      Modulares Design, grafische Dialoge, Endlosschleife
# Author:           Tobias B
# ==============================================================================

set -euo pipefail

PROVISION_SCRIPT="./user_provisioning.sh"
DEPROVISION_SCRIPT="./user_deprovisioning.sh"
LOG_FILE="./userlog.md"

# ==============================================================================
# Funktion: check_requirements
# Zweck:    Prueft administrative Rechte und alle notwendigen Systemkomponenten
# ==============================================================================
check_requirements() {
    if [[ $EUID -ne 0 ]]; then
        echo "Kritischer Fehler: Das Skript erfordert administrative Rechte."
        exit 1
    fi

    if ! command -v whiptail &> /dev/null; then
        echo "Kritischer Fehler: Das Paket whiptail ist nicht installiert."
        exit 1
    fi

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
# Funktion: show_log
# Zweck:    Liest die Protokolldatei ein und stellt sie in einer scrollbaren Textbox dar
# ==============================================================================
show_log() {
    if [[ -f "$LOG_FILE" ]]; then
        whiptail --title "Verarbeitungsprotokoll" --scrolltext --textbox "$LOG_FILE" 22 80
    else
        whiptail --title "Dateifehler" --msgbox "Die Protokolldatei existiert noch nicht im System." 8 50
    fi
}

# ==============================================================================
# Funktion: print_log
# Zweck:    Liest verfuegbare Drucker aus und sendet die Datei an das gewaehlte Ziel
# ==============================================================================
print_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        whiptail --title "Druckfehler" --msgbox "Die Protokolldatei existiert nicht und kann nicht gedruckt werden." 8 50
        return
    fi

    if ! command -v lp &> /dev/null; then
        whiptail --title "Systemfehler" --msgbox "Der Druckdienst lp ist nicht installiert." 8 50
        return
    fi

    local printers
    printers=$(lpstat -e 2>/dev/null)

    if [[ -z "$printers" ]]; then
        whiptail --title "Druckfehler" --msgbox "Es wurden keine konfigurierten Drucker im System gefunden." 8 50
        return
    fi

    local menu_options=()
    while IFS= read -r printer; do
        menu_options+=("$printer" "Drucker")
    done <<< "$printers"

    local selected_printer
    selected_printer=$(whiptail --title "Druckerauswahl" \
                               --menu "Bitte waehlen Sie das Zielgeraet:" 15 60 6 \
                               "${menu_options[@]}" 3>&1 1>&2 2>&3)

    if [[ -z "$selected_printer" ]]; then
        return
    fi

    local print_error
    if print_error=$(lp -d "$selected_printer" "$LOG_FILE" 2>&1); then
        whiptail --title "Druckstatus" --msgbox "Die Datei wurde erfolgreich an $selected_printer uebermittelt." 8 50
    else
        whiptail --title "Druckfehler" --msgbox "Der Druckauftrag ist fehlgeschlagen. Systemmeldung:\n\n$print_error" 12 70
    fi
}

# ==============================================================================
# Funktion: main_menu
# Zweck:    Stellt das interaktive Hauptmenue via whiptail dar und steuert Logik
# ==============================================================================
main_menu() {
    local choice

    while true; do
        choice=$(whiptail --title "Benutzerverwaltung Manager" \
                          --menu "Bitte waehlen Sie eine Systemaktion:" 18 65 6 \
                          "1" "Benutzer automatisiert anlegen" \
                          "2" "Benutzer interaktiv loeschen" \
                          "3" "Protokolldatei anzeigen" \
                          "4" "Protokolldatei drucken" \
                          "5" "Programm beenden" 3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]]; then
            break
        fi

        case "$choice" in
            1)
                whiptail --title "Systemstatus" --msgbox "Starte Provisionierung" 8 45
                clear
                "$PROVISION_SCRIPT"
                echo ""
                read -r -p "ENTER druecken fuer Rueckkehr zum Menue" _
                ;;
            2)
                whiptail --title "Systemstatus" --msgbox "Starte Deprovisionierung" 8 45
                clear
                "$DEPROVISION_SCRIPT"
                echo ""
                read -r -p "ENTER druecken fuer Rueckkehr zum Menue" _
                ;;
            3)
                show_log
                ;;
            4)
                print_log
                ;;
            5)
                break
                ;;
        esac
    done

    clear
    echo "Programm erfolgreich beendet."
}

# ==============================================================================
# Hauptprogramm
# ==============================================================================
main() {
    check_requirements
    main_menu
}

main
