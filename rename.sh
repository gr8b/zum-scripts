#!/bin/bash

# Checking requirements
command -v jq &> /dev/null || { echo "jq is required"; exit 1; }

widget_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            shift
            widget_dir="${1%/}"
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

manifest="$widget_dir/manifest.json"
[ ! -e "$manifest" ] || [ ! -w "$manifest" ] && { echo "No manifest.json file found."; exit 1; }

id=$(jq -r '.id' $manifest)
name=$(jq -r '.name' $manifest)
type=$(jq -r '.type' $manifest)
namespace=$(jq -r '.namespace' $manifest)
js_class=$(jq -r 'if .widget | has("js_class") then .widget.js_class else empty end' "$manifest")

echo "id        $id"
echo "name      $name"
echo "type      $type"
echo "namespace $namespace"

read -p "New value for id $id (clone_$id): " new_id
new_id=${new_id:-"clone_$id"}
read -p "New value for name $name (My $name): " new_name
new_name=${new_name:-"My $name"}
read -p "New value for namespace $namespace (My$namespace): " new_namespace
new_namespace=${new_namespace:-"My$namespace"}

# Modify manifest.json
json=$(jq \
        --arg id "$new_id" \
        --arg name "$new_name" \
        --arg namespace "$new_namespace" \
    '
    .id = $id |
    .name = $name |
    .namespace = $namespace
    ' $manifest)

# Modify manifest.json actions
if [[ "$type" == "widget" ]]; then
    php_namespace=$(grep -E '^namespace ' "$widget_dir/Widget.php" | sed -E 's/^namespace (.*);/\1/')
    php_namespace_escaped=$(printf '%s\n' "$php_namespace" | sed 's/[\/&]/\\&/g')
    new_php_namespace="Modules\\$new_namespace"
    new_php_namespace_escaped=$(printf '%s\n' "$new_php_namespace" | sed 's/[\/&]/\\&/g')

    # Widget actions
    json=$(jq --arg id "$id" --arg new_id "$new_id" \
    '
        .actions |= with_entries(
            .key |= gsub("widget\\." + $id + "\\."; "widget." + $new_id + ".")
        )
    ' <<< "$json")

    # Prefix every occurency of javascript class name with $namespace_
    if [[ -n "$js_class" ]]; then
        new_js_class="${new_namespace}_${js_class}"

        json=$(jq --arg js_class "$new_js_class" '.widget.js_class = $js_class' <<< "$json")

        if [[ -d "$widget_dir/assets/js" ]]; then
            sed -i "s|$js_class|$new_js_class|g" $widget_dir/assets/js/*
        fi
    fi

    # Update default widget name
    sed -i "s|['\"]$name['\"]|'$new_name'|g" $widget_dir/Widget.php
    sed -i "s|namespace $php_namespace_escaped;|namespace $new_php_namespace_escaped;|g" $widget_dir/Widget.php

else
    # Module actions
    echo "Not yet implemented!"

    exit 1
fi

# Save modified manifest.json
echo "$json" | jq '.' | sed 's/  /\t/g' > $manifest

# Update namespace and use declarations in directories actions/ and includes.
dirs=("actions" "includes")

for dir in "${dirs[@]}"; do
    if [[ -d "$widget_dir/$dir" ]]; then
        dir_capitalized="$(tr '[:lower:]' '[:upper:]' <<< "${dir:0:1}")${dir:1}"

        find "$widget_dir/$dir" -type f -name "*.php" -exec sed -i "s|namespace $php_namespace_escaped\\\\$dir_capitalized;|namespace $new_php_namespace_escaped\\\\$dir_capitalized;|g" {} +
        find "$widget_dir/$dir" -type f -name "*.php" -exec sed -i "s|use $php_namespace_escaped\\\\$dir_capitalized|use $new_php_namespace_escaped\\\\$dir_capitalized|g" {} +
    fi
done

if [[ -d "$widget_dir/views" ]]; then
    find "$widget_dir/views" -type f -name "*.php" -exec sed -i "s|use $php_namespace_escaped\\\\|use $new_php_namespace_escaped\\\\|g" {} +
fi






