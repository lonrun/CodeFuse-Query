#!/bin/bash
set +x

# Check if the parameter is empty
if [ -z "$1" ]; then
  echo "Please provide a directory as an argument"
  exit 1
fi

# Change to the directory
cd "$1" || exit 1

sparrow_godel_script="$HOME/sparrow-cli/godel-script/usr/bin/godel"
sparrow_lib_1_0="$HOME/sparrow-cli/lib-1.0"

# Define get_files function
get_files() {
  local directory="$1"
  local extension="$2"
  
  find "$directory" -type f -name "*$extension" -print
}

# Define rebuild_lib function
rebuild_lib() {
  TMPDIR="."
  local lib_path="$1"
  local lib="$2"
  local file_list
  gdl_list=()
  gdl_list+=($(get_files "$lib_path" ".gs"))
  gdl_list+=($(get_files "$lib_path" ".gdl"))
  output_file=$(mktemp -p "$TMPDIR" "tempfile.XXXXXX.gdl")
  echo "// script" > "$output_file"
  for file_name in "${gdl_list[@]}"; do
    cat "$file_name" >> "$output_file"
  done
  cmd=()
  tmp_out=$(mktemp -p "$TMPDIR" "tempfile.XXXXXX.gdl")
  cmd+=("$sparrow_godel_script" "$output_file" "-o" "$tmp_out")
  start_time=$(date +%s%3N)
  "${cmd[@]}"
  return_code=$?
  if [ "$return_code" != "0" ]; then
    echo "$lib_path lib compile error, please check it yourself" >&2
    exit 1
  fi
  cp "$tmp_out" "$sparrow_lib_1_0/coref.$lib.gdl"
  end_time=$(date +%s%3N)
  elapsed_time=$((end_time - start_time))
  echo "$lib_path lib compile success time: $elapsed_time milliseconds" >&2

  # remove tmp files
  rm "$output_file"
  rm "$tmp_out"
}

# Define get_language function
get_language() {
  local directories=("$@")
  
  for dir in "${directories[@]}"; do
    local dirname=$(dirname "$dir")
    local language=$(basename "$dirname")
    
    echo "$language"
    return
  done
}

echo "Checking Libs: $files"

# Get libs directories
directories=($(find "$PWD" -type d \( -path "$PWD/language/*/lib" -o -path "$PWD/language/*/libs" \) -print))

# Get libs 
for dir in "${directories[@]}"; do
    echo "$dir"
    lang=$(get_language "$dir")
    echo "build lib for $lang ..."
    rebuild_lib "$dir" "$lang"
done

# Define get_target_files function
get_target_files() {
  local files=$(find "$1" -type f \( -name "*.gs" -o -name "*.gdl" \) -not -path "$1/language/*/lib/*")
  echo "$files"
}

files=$(get_target_files "$PWD")
echo "Checking Files: $files"

# Iterate over the files
for file in $files; do
  echo "Checking file $file ..."
  
  # Run the godel command and capture the output
  output=$("$sparrow_godel_script" "$file" "-p" "$sparrow_lib_1_0" -o "${file%.*}_tmp.gdl" 2>&1)
  
  # Check if the output is not empty
  if [ -n "$output" ]; then
    echo "The file $file produced the following output:"
    echo "$output"
    echo "Please check if this file is a godel script (.gs) or a godel 1.0 script (.gdl)"
    exit 1
  else
    echo "$file build successful"
  fi
  
  # Remove temporary file
  if [ -f "${file%.*}_tmp.gdl" ]; then
    rm "${file%.*}_tmp.gdl"
  fi
done

# Exit normally if there is no output
exit 0
