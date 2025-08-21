#!/bin/bash

# Script dispatcher for get_target.sh and run_target.sh
# Usage: ./script.sh get <args...>  or  ./script.sh run <args...>

if [ $# -eq 0 ]; then
    echo "Usage: $0 {get|run} [arguments...]"
    echo "  get - runs get_target.sh with the provided arguments"
    echo "  run - runs run_target.sh with the provided arguments"
    exit 1
fi

COMMAND="$1"
shift  # Remove the first argument, leaving the rest for the target scripts

case "$COMMAND" in
    get)
        if [ -f "get_target.sh" ]; then
            bash get_target.sh "$@"
        else
            echo "Error: get_target.sh not found in current directory"
            exit 1
        fi
        ;;
    run)
        if [ -f "run_target.sh" ]; then
            bash run_target.sh "$@"
        else
            echo "Error: run_target.sh not found in current directory"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        echo "Usage: $0 {get|run} [arguments...]"
        exit 1
        ;;
esac