#!/bin/bash

log_file="/dev/null"

print_help() {
  echo "This script is for converting videos to compressed mkv files in order to save space"
  echo ""
  echo "Options:"
  echo ""
  echo "-f | --file         CSV file containing input and output file names (Required)."
  echo "                    Format of the csv file:"
  echo "                    input_path;output_path"
  echo "                    Use only full file paths!"
  echo "-l | --log-file     Path to the log file, default is /home/sams/custom_scripts/convert_videos.log." 
  echo "                    If no log file is speified, nothing gets logged"
  echo "-h | --help         Print this help message."
}

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -f|--file)
      i_o_csv="$2"
      shift # past argument
      shift # past value
      ;;
    -l|--log-file)
      log_file="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      print_help
      exit 0
      ;;
  esac
done

if ! [[ -v i_o_csv ]]
then
  echo "Please specify the path to a csv file containing input and output file paths"
  echo "Exiting..."
  exit 0
fi

logfile_dirname=$(dirname "$log_file")
mkdir -pv "$logfile_dirname"
echo -e "Starting Video Conversion Script\n" | tee "$log_file"

skipped_files=()
conversion_failed=()
conversion_succeeded=()
number_of_input_lines=$(wc -l $i_o_csv | cut -d" " -f1)
current_input_line=1

while IFS=";" read input_name output_name 
do
  echo "---------------------------"
  echo "Converting file ( $current_input_line / $number_of_input_lines ) "
  echo "---------------------------"
  current_input_line=$((current_input_line+1))
  
  # check if input file exists and is readable by the user
  if ! [[ -r "$input_name" ]]
  then
    echo "File $input_name does not exists or user has no permission to read it." | tee -a "$log_file"
    echo "Skipping file..." | tee -a "$log_file"
    skipped_files+=("\n$input_name")
    continue
  fi

  # check if output file already exists
  if [[ -a "$output_name" ]]
  then
    echo "Output file $output_name does already exist." | tee -a "$log_file"
    echo "Skipping file..." | tee -a "$log_file"
    skipped_files+=("\n$input_name")
    continue
  fi

  # create output directory if it does not exist
  output_dirname=$(dirname "$output_name")
  mkdir -pv "$output_dirname" | tee -a "$log_file"

  # convert video file
  ffmpeg -nostdin -i "$input_name" -c:v libx265 -map 0 -c:s copy -crf 20 "$output_name" | tee -a "$log_file"

  # check for the exit code of ffmpeg to determine success (=delete the source file) or failure (=delete destination)
  if [[ ${PIPESTATUS[0]} -eq 0 ]]
  then
    echo "Conversion succeeded. Deleting source file..." | tee -a "$log_file"
    rm -v "$input_name" | tee -a "$log_file"
    conversion_succeeded+=("\n$input_name")
  else
    echo "Conversion failed. Deleting destination file - might be incomplete or corrupt..." | tee -a "$log_file"
    rm -v "$output_name" | tee -a "$log_file"
    conversion_failed+=("\n$input_name")
  fi

  # removing input and output directories (and their parents) if they are empty
  output_dirname=$(dirname "$output_name")
  rmdir -pv "$output_dirname" | tee -a "$log_file"
  input_dirname=$(dirname "$input_name")
  rmdir -pv "$input_dirname" | tee -a "$log_file"
  echo "input: $input_name"
  echo "output: $output_name"
done < $i_o_csv

echo -e "\nExecution finished." | tee -a "$log_file"
echo -e "Skipped input files: ${skipped_files[*]}" | tee -a "$log_file"
echo -e "Failed input files: ${conversion_failed[*]}" | tee -a "$log_file"
echo -e "Successful input files: ${conversion_succeeded[*]}" | tee -a "$log_file"



