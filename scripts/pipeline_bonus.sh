
#Download all the files specified in data/urls
echo "Downloading files..."
wget -nc -P data -i data/urls
echo

# Download the contaminants fasta file, and uncompress it
echo "Downloading and uncompressing contaminants file..."
cont=res/contaminants.fasta.gz
if [ -f $cont ]
then
	echo "$cont already exists"
else
	bash scripts/download.sh https://bioinformatics.cnio.es/data/courses/decont/contaminants.fasta.gz res yes
fi
echo

# Index the contaminants file
echo "Running STAR index..."
idx=res/contaminants_idx
if [ -d $idx ]
        then
                echo "$idx already exists"
        else
                bash scripts/index.sh res/contaminants.fasta res/contaminants_idx
fi
echo

# Merge the samples into a single file
echo "Merging samples..."
for sid in $(ls data/*.fastq.gz | cut -d"-" -f1 | sed "s:data/::" | sort | uniq)
do
        if [ -f out/merged/${sid}.fastq.gz ]
        then
                echo "out/merged/${sid}.fastq.gz already exists"
        else
                bash scripts/merge_fastqs.sh data out/merged $sid
        fi
done
echo

# Run cutadapt for all merged files
echo "Running cutadapt..."
mkdir -p out/trimmed
mkdir -p log/cutadapt
for sid in $(ls out/merged/*.fastq.gz | cut -d "." -f1 | sed 's:out/merged/::')
do
	if [ -f log/cutadapt/${sid}.log ]
	then
		echo "log/cutadapt/${sid}.log already exists"
	else
		cutadapt -m 18 -a TGGAATTCTCGGGTGCCAAGG --discard-untrimmed -o  out/trimmed/${sid}.trimmed.fastq.gz out/merged/${sid}.fastq.gz > log/cutadapt/${sid}.log
	fi
done
echo

# Run STAR for all trimmed files
echo "Running STAR alignment..."
for fname in out/trimmed/*.fastq.gz
do
    # you will need to obtain the sample ID from the filename
    sid=$(basename $fname .trimmed.fastq.gz)
    if [ -d out/star/$sid ]
	then
		echo "out/star/$sid already exists"
	else
    		mkdir -p out/star/$sid
		STAR --runThreadN 4 --genomeDir res/contaminants_idx --outReadsUnmapped Fastx --readFilesIn out/trimmed/${sid}.trimmed.fastq.gz --readFilesCommand zcat --outFileNamePrefix out/star/${sid}/
	fi
done 
echo

# create a log file containing information from cutadapt and star logs
# (this should be a single log file, and information should be *appended* to it on each run)
# - cutadapt: Reads with adapters and total basepairs
# - star: Percentages of uniquely mapped reads, reads mapped to multiple loci, and to too many loci
echo "Creating a report..."
if [ -f log/pipeline.log ]
then
	echo "log/pipeline.log already exists"
else
	for sid in $(ls out/merged/*.fastq.gz | cut -d "." -f1 | sed 's:out/merged/::')
	do
		echo "			~~~ ${sid} sample ~~~" >> log/pipeline.log
		echo >> log/pipeline.log
        	cat log/cutadapt/${sid}.log | grep "Reads with adapters:" >> log/pipeline.log
        	cat log/cutadapt/${sid}.log | grep "Total basepairs processed:" >> log/pipeline.log
        	cat out/star/${sid}/Log.final.out | grep "Uniquely mapped reads %" >> log/pipeline.log
        	cat out/star/${sid}/Log.final.out | grep "% of reads mapped to multiple loci" >> log/pipeline.log
        	cat out/star/${sid}/Log.final.out | grep "% of reads mapped to too many loci" >> log/pipeline.log
		echo >> log/pipeline.log
	done
fi

