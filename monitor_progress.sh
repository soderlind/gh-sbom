#!/bin/bash

# Simple progress monitor for the SBOM generation script

echo "SBOM Generation Progress Monitor"
echo "================================="

while true; do
    if [[ -f "debug_run.log" ]]; then
        current_repo=$(tail -10 debug_run.log | grep "About to process repo" | tail -1 | sed 's/.*repo #\([0-9]*\).*/\1/')
        if [[ -n "$current_repo" ]]; then
            percentage=$((current_repo * 100 / 145))
            echo "$(date): Processing repository $current_repo/145 ($percentage%)"
        fi
    fi
    
    # Check if process is still running
    if ! pgrep -f "gh-sbom-all.sh" > /dev/null; then
        echo "$(date): Script has completed!"
        break
    fi
    
    sleep 30
done
