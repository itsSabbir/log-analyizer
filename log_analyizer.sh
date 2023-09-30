#!/bin/bash

# Advanced Log Analyzer with Enhancements

LOG_FILE="/var/log/syslog"
DB_FILE="/tmp/log_analyzer.db"
ALERT_THRESHOLD=10
EMAIL_RECIPIENT="your_email@example.com"

echo "Welcome to the Enhanced Log Analyzer"

function setup_database {
    # Initialize the database if it doesn't exist
    if [[ ! -f $DB_FILE ]]; then
        sqlite3 $DB_FILE "CREATE TABLE logs (date TEXT, service TEXT, content TEXT);"
        # Populate the database with logs
        cat $LOG_FILE | while read line; do
            date=$(echo $line | cut -d' ' -f1,2,3)
            service=$(echo $line | cut -d' ' -f5)
            content=$(echo $line | cut -d' ' -f6-)
            sqlite3 $DB_FILE "INSERT INTO logs (date, service, content) VALUES ('$date', '$service', '$content');"
        done
    fi
}

function menu {
    echo
    echo "Please choose an option:"
    echo "1. View logs for a specific date"
    echo "2. View logs for a specific service (e.g., sshd, systemd)"
    echo "3. View logs for a specific user"
    echo "4. Security Report"
    echo "5. System Health"
    echo "6. Custom Query"
    echo "7. Visual Reports"
    echo "8. Exit"
    read -p "Enter your choice: " choice
}

function security_report {
    echo "Security Concerns:"
    echo "Failed login attempts:"
    failed_attempts=$(sqlite3 $DB_FILE "SELECT COUNT(*) FROM logs WHERE content LIKE '%Failed password%';")
    echo "Total Failed Attempts: $failed_attempts"
    
    if [[ $failed_attempts -gt $ALERT_THRESHOLD ]]; then
        echo "Sending email alert..."
        echo "High number of failed login attempts detected: $failed_attempts" | mail -s "Security Alert" $EMAIL_RECIPIENT
    fi
    
    echo
    echo "Possible unauthorized access:"
    sqlite3 $DB_FILE "SELECT content FROM logs WHERE content LIKE '%Accepted password%';"
}

function system_health {
    echo "System Errors:"
    sqlite3 $DB_FILE "SELECT content FROM logs WHERE content LIKE '%error%';"
    echo
    echo "System Warnings:"
    sqlite3 $DB_FILE "SELECT content FROM logs WHERE content LIKE '%warning%';"
}

function visual_reports {
    read -p "Enter service name for visual report: " service_filter
    echo "Generating histogram for $service_filter logs..."

    sqlite3 $DB_FILE "SELECT date, COUNT(*) FROM logs WHERE service LIKE '%$service_filter%' GROUP BY date;" > /tmp/histogram_data.txt

    echo "set terminal png
    set output '/tmp/report.png'
    set boxwidth 0.5
    set style fill solid
    set xlabel 'Time'
    set ylabel 'Count'
    set title 'Log Frequency for $service_filter'
    plot '/tmp/histogram_data.txt' using 2:xtic(1) with boxes" | gnuplot

    echo "Report generated as /tmp/report.png"
}

setup_database

while true; do
    menu
    case $choice in
        1)
            read -p "Enter date (format: MMM dd, e.g., Sep 26): " date_filter
            sqlite3 $DB_FILE "SELECT content FROM logs WHERE date LIKE '%$date_filter%';"
            ;;
        2)
            read -p "Enter service name: " service_filter
            sqlite3 $DB_FILE "SELECT content FROM logs WHERE service LIKE '%$service_filter%';"
            ;;
        3)
            read -p "Enter username: " user_filter
            sqlite3 $DB_FILE "SELECT content FROM logs WHERE content LIKE '%$user_filter%';"
            ;;
        4)
            security_report
            ;;
        5)
            system_health
            ;;
        6)
            read -p "Enter custom query: " custom_filter
            sqlite3 $DB_FILE "SELECT content FROM logs WHERE content LIKE '%$custom_filter%';"
            ;;
        7)
            visual_reports
            ;;
        8)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done
