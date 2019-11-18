# This script should merge all files from a given sample (the sample id is provided in the third argument)
# into a single file, which should be stored in the output directory specified by the second argument.
# The directory containing the samples is indicated by the first argument.

mkdir -p $2
cat $1/$3-12.5dpp.1.1s_sRNA.fastq.gz data/$3-12.5dpp.1.2s_sRNA.fastq.gz > $2/$3.fastq.gz 
