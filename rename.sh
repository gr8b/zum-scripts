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
    shift  # Move to the next argument
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
else
    # Module actions
    echo "Not yet implemented!"

    exit 1
fi

# Save modified manifest.json
echo "$json" | jq '.' | sed 's/  /\t/g' > $manifest

# Update namespace in .php files
if [[ -d "$widget_dir/actions" ]]; then
    find "$widget_dir/actions" -type f -name "*.php" -exec sed -i "s|namespace .*\\$namespace\\\\Actions;|namespace Modules\\\\$new_namespace\\\\Actions;|g" {} +
fi

if [[ -d "$widget_dir/includes" ]]; then
    sed -i "s|namespace .*\\$namespace\\\\Includes;|namespace Modules\\\\$new_namespace\\\\Includes;|g" "$widget_dir/includes/WidgetForm.php"
fi

sed -i "s|namespace .*\\$namespace;|namespace Modules\\\\$new_namespace;|g" $widget_dir/Widget.php






