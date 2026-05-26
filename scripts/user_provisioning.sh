#!/bin/bash

# ==============================================================================
# Skriptname:       user_provisioning.sh
# Version:          1.1
# Zweck:            Automatisierte Erstellung von Benutzerkonten aus einer CSV Datei
# Parameter:        Keine
# Rueckgabewert:    0 bei fehlerfreier Ausfuehrung, 1 bei Abbruechen
# Voraussetzungen:  Administrative Rechte, Paket pwgen
# Architektur:      Separation of Concerns, Modularisierung, Fail Fast Ansatz
# Author:           Tobias B
# ==============================================================================

# Sicherheitsrichtlinien für Bash-Ausführung erzwingen
set -e
set -o pipefail

# ==============================================================================
# Globale Variablen und Konstanten
# ==============================================================================
INPUT_CSV="Abwesenheit_Generated_25.csv"
CLEANED_CSV="cleaned_users.csv"
LOG_FILE="userlog.md"
CREDENTIALS_FILE="credentials.csv"

# ==============================================================================
# Funktion: check_root
# Zweck:    Prueft ob das Skript mit administrativen Rechten ausgefuehrt wird
# ==============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Kritischer Fehler: Das Skript erfordert administrative Rechte."
        exit 1
    fi
}

# ==============================================================================
# Funktion: check_dependencies
# Zweck:    Prueft das Vorhandensein des Pakets pwgen und installiert dieses
#           bei Bedarf automatisch ueber den systemspezifischen Paketmanager.
# Rueckgabewert: Beendet das Skript mit Code 1 bei fehlschlagender Installation
# ==============================================================================
check_dependencies() {
    if ! command -v pwgen &> /dev/null; then
        echo "System: Das Paket pwgen fehlt. Starte automatische Installation."

        # Dynamische Erkennung des Paketmanagers fuer verschiedene Distributionen
        if command -v apt-get &> /dev/null; then
            DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y pwgen
        elif command -v pacman &> /dev/null; then
            pacman -Sy --noconfirm pwgen
        elif command -v dnf &> /dev/null; then
            dnf install -y pwgen
        else
            echo "Kritischer Fehler: Kein unterstuetzter Paketmanager gefunden."
            exit 1
        fi

        # Abschliessende Validierung des Installationsvorgangs
        if ! command -v pwgen &> /dev/null; then
            echo "Kritischer Fehler: Automatische Installation fehlgeschlagen."
            exit 1
        fi
        
        echo "System: Paket pwgen erfolgreich installiert."
    fi
}

# ==============================================================================
# Funktion: log_action
# Zweck:    Protokolliert einen Verarbeitungsschritt in Datei und Terminal
# Parameter:
#   $1 : Zu protokollierende Nachricht
# ==============================================================================
log_action() {
    local message="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "* ${timestamp} : ${message}" | tee -a "$LOG_FILE"
}

# ==============================================================================
# Funktion: clean_csv
# Zweck:    Erstellt die bereinigte Zwischendatei durch Filtern valider Zeilen
# ==============================================================================
clean_csv() {
    log_action "System: Starte Bereinigung der Quelldatei"
    
    # Fehler ignorieren und Zeilenumbrueche plattformunabhaengig normieren
    tr '\r' '\n' < "$INPUT_CSV" | grep -E '^[0-9]+;' > "$CLEANED_CSV" || true
    
    log_action "System: Bereinigung abgeschlossen und Zwischendatei erstellt"
}

# ==============================================================================
# Funktion: process_users
# Zweck:    Liest die Zwischendatei iterativ ein und führt die Anlage durch
# ==============================================================================
process_users() {
    log_action "System: Starte Iteration zur Benutzeranlage"

    echo "Benutzername;Passwort" > "$CREDENTIALS_FILE"
    
    chmod 644 "$CREDENTIALS_FILE"

    while IFS=";" read -r id nachname vorname rest; do
        
        # Bereinigung von Leerzeichen und Steuerzeichen
        local vorname_clean="${vorname//[ $'\r']/}"
        local nachname_clean="${nachname//[ $'\r']/}"
        
        # Konvertierung in durchgaengige Kleinschreibung
        local vorname_lower="${vorname_clean,,}"
        local nachname_lower="${nachname_clean,,}"
        
        # Normalisierung der Umlaute zwingend vor der Kuerzung
        local vorname_norm
        vorname_norm=$(echo "$vorname_lower" | sed -e 's/ä/ae/g' -e 's/ö/oe/g' -e 's/ü/ue/g' -e 's/ß/ss/g')
        
        local nachname_norm
        nachname_norm=$(echo "$nachname_lower" | sed -e 's/ä/ae/g' -e 's/ö/oe/g' -e 's/ü/ue/g' -e 's/ß/ss/g')
        
        # Extraktion der finalen Praefixe auf exakt drei Zeichen
        local vorname_prefix="${vorname_norm:0:3}"
        local nachname_prefix="${nachname_norm:0:3}"
        
        # Zusammensetzung des Kontonamens
        local username="${vorname_prefix}${nachname_prefix}"
        
        local gecos="${vorname_clean} ${nachname_clean}"
        
        local raw_pw
        raw_pw=$(pwgen -1 -s 12)
        local userpasswort="${username}${raw_pw}"
        
        echo -e "\n### Benutzerprofil: ${gecos}" | tee -a "$LOG_FILE"
        echo "**Initialpasswort:** ${userpasswort}" | tee -a "$LOG_FILE"
        
        log_action "Account ${username}: Namenskonvention und Variablen generiert"
        
        if id "$username" &>/dev/null; then
            log_action "Account ${username}: Uebersprungen da Konto existiert"
            continue
        fi
        
        useradd -m -c "$gecos" -s /bin/bash "$username"
        log_action "Account ${username}: Konto erfolgreich angelegt"
        
        echo "${username}:${userpasswort}" | chpasswd
        log_action "Account ${username}: Systempasswort zugewiesen"
        
        echo "${username};${userpasswort}" >> "$CREDENTIALS_FILE"
        
    done < "$CLEANED_CSV"
    
    log_action "System: Alle Benutzerkonten vollstaendig verarbeitet"
}
# ==============================================================================
# Hauptprogramm
# ==============================================================================
main() {
    echo "# Verarbeitungsprotokoll Benutzerverwaltung" > "$LOG_FILE"
    
    check_root
    check_dependencies
    clean_csv
    process_users
}

main
