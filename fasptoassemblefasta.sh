#!/bin/bash

# Set the path to the mother folder containing subfolders A to E
mother_folder=absolute path to the directory of the fastq file assmebled in separate folder

# Function to filter contig sequences longer than 200 base pairs
filter_contigs() {
    input_fasta="$1"
    output_fasta="$2"
    seqkit seq -m 200 "$input_fasta" > "$output_fasta"
}

# Loop through each subfolder and process the paired-end sequences
for folder in "$mother_folder"/*; do
# Check if the item is a directory
    if [[ -d "$folder" ]]; then
            # Check if the directory is one of the excluded directories
        if [[ "$folder" == */contigs* ]]; then
            echo "Skipping directory $(basename "$folder")."
            continue
        fi
    echo "Processing folder $(basename "$folder")..."

    # Clear the contents of the subfolder, except R1 and R2 files
    find "$folder" -mindepth 1 ! -name "$(basename "$folder")_R1.fastq.gz" ! -name "$(basename "$folder")_R2.fastq.gz" -delete
    
    # Trim the sequences using fastp
    echo "Running fastp for $(basename "$folder")..."
    fastp -i "$folder/$(basename "$folder")_R1.fastq.gz" \
          -I "$folder/$(basename "$folder")_R2.fastq.gz" \
          -f 20 -F 20 -t 10 -T 10 -r -l 40 \
          -o "$folder/$(basename "$folder")_trimmed_R1.fastq" \
          -O "$folder/$(basename "$folder")_trimmed_R2.fastq" | tee "$folder/fastp.log"
    
    # Create a text file containing the trimmed file names for use in fastuniq
    echo "$folder/$(basename "$folder")_trimmed_R1.fastq" >> "$folder/fastuniq.txt"
    echo "$folder/$(basename "$folder")_trimmed_R2.fastq" >> "$folder/fastuniq.txt"
    
    # Use fastuniq to merge the trimmed files
    echo "Running fastuniq for $(basename "$folder")..."
    fastuniq -t q -i "$folder/fastuniq.txt" -o "$folder/$(basename "$folder")_final_R1.fastq" -p "$folder/$(basename "$folder")_final_R2.fastq" | tee "$folder/fastuniq.log"
    
    # Remove the trimmed files
    echo "Deleting trimmed files for $(basename "$folder")..."
    rm "$folder/$(basename "$folder")_trimmed_R1.fastq" "$folder/$(basename "$folder")_trimmed_R2.fastq"
    
    # Compress the final FASTQ files
    echo "Compressing final FASTQ files for $(basename "$folder")..."
    pigz "$folder/$(basename "$folder")_final_R1.fastq" "$folder/$(basename "$folder")_final_R2.fastq"
    
    # Use SPAdes to assemble the merged sequences
    echo "Running SPAdes for $(basename "$folder")..."
    spades -1 "$folder/$(basename "$folder")_final_R1.fastq.gz" -2 "$folder/$(basename "$folder")_final_R2.fastq.gz" -t 26 --cov-cutoff auto --careful -o "$folder/$(basename "$folder")" | tee "$folder/spades.log"

    # Filter contig sequences longer than 200 base pairs
    echo "Filtering contig sequences for $(basename "$folder")..."
    contigs_folder="$mother_folder/contigs"
    mkdir -p "$contigs_folder"
    contigs_fasta="$folder/$(basename "$folder")/contigs.fasta"
    filtered_contigs_fasta="$contigs_folder/$(basename "$folder").fasta"
    filter_contigs "$contigs_fasta" "$filtered_contigs_fasta"
    else
    echo echo "Skipping file $(basename "$folder") as it is not a directory."
    fi
done

# Change the working directory to the contigs directory
contigs_folder="$mother_folder/contigs"
cd "$contigs_folder"

#creating folder to keep the output of the annotated files
prokka_directory="$mother_folder/prokka"
mkdir $prokka_directory

#running prokka for the contig files
for sequence_file in ./*.fasta; do
    filename="${sequence_file##*/}"  # Extract only the file name
    filename="${filename%.fasta}"     # Remove the file extension
    # Create a separate output directory for the current sequence
    output_directory="$prokka_directory/$sequence_name"
    mkdir -p "$output_directory"
    # Run Prokka on the current multi-fasta contig file
    prokka --outdir "$output_directory" --force --locustag "$filename" --prefix "$filename" "$sequence_file"
done

echo "Script execution completed."
