#!/bin/bash

# Set the path to the mother folder containing subfolders A to E for mapping
mother_folder="absolute path to the directory of the fastq file assembled in separate folder"

reference_genome="absolute path of the reference genome"

# Loop through each subfolder and process the paired-end sequences
for folder in "$mother_folder"/*; do
    # Check if the item is a directory
    if [[ -d "$folder" ]]; then
        echo "Processing folder $(basename "$folder")..."
        
        # Create an output directory based on the current subfolder
        output_dir="snippy/$(basename "$folder")"
        
        # Make sure the output directory exists
        mkdir -p "$output_dir"
        
        # Trim the sequences using fastp
        echo "Running snippy for $(basename "$folder")..."
        fastp --R1 "$folder/$(basename "$folder")_R1.fastq.gz" \
              --R2 "$folder/$(basename "$folder")_R2.fastq.gz" \
              --ref "$reference_genome" \
              --outdir "$output_dir"
    else
        echo "Skipping file $(basename "$folder") as it is not a directory."
    fi
done

echo "Script execution completed."

