#!/bin/bash

# Prosty skrypt do wysyłania zapytań do TinyLLM
# Użycie: ./simple_ask.sh "Twoje pytanie"

if [ -z "$1" ]; then
  echo "Podaj pytanie jako argument!"
  echo "Przykład: ./simple_ask.sh \"Co to jest Python?\""
  exit 1
fi

# Escaping cudzysłowów w pytaniu
PROMPT=$(echo "$1" | sed 's/"/\\"/g')

# Tworzenie JSON i wysyłanie zapytania
JSON="{\"prompt\":\"$PROMPT\"}"
echo "Wysyłanie zapytania: $1"
echo "JSON: $JSON"

# Wysłanie zapytania za pomocą curl (w jednej linii)
curl -s -X POST -H "Content-Type: application/json" -d "$JSON" http://localhost:5001/ask | jq -r '.response'