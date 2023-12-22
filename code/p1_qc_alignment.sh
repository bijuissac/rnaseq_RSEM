#!/usr/bin/sh

#working directory
echo "Moving to working directory"
cd /home/ec2-user/
mkdir -p results results/multiqc results/rsem_outs results/pretrim_fastqc results/aligned_bams results/trimmed_fastqs results/cutadapt results/postrim_fastqc

#data folders
data_dir=data/fastqs
star_ref=data/STAR_references/STAR/2.7.11a/genome
rsem_ref=data/rsem_references
anno_dir=data/genome_assembly_files

#convert adapter file into tab limited format
adapter_file="data/TruSeq_and_nextera_adapters.consolidated.fa"
fastqc_adapter="code/adapter.fa"

perl code/convert_adapter.pl $adapter_file $fastqc_adapter

#create sample_list file
ls -l data/fastqs | awk '{ print substr($9,1,8) }' | sort -u | grep Rep > sample_list.txt

#Pre-Trimming Fastqc
echo "Generating RAW fastqc"
fastqc -o results/pretrim_fastqc -a $fastqc_adapter -f fastq $data_dir/*.gz

#Trimming using Cutadapt
while IFS= read -r line; do
    case=$(echo $line)
    echo "Processing file $case"
    file1=$data_dir"/"$case".R1.fastq.gz"
    file2=$data_dir"/"$case".R2.fastq.gz"
    file1o="results/trimmed_fastqs/"$case".R1.trimmed_fastq.gz"
    file2o="results/trimmed_fastqs/"$case".R2.trimmed_fastq.gz"

    cutadapt -a "file:data/TruSeq_and_nextera_adapters.consolidated.fa;min_overlap=5;noindels" -o $file1o -p $file2o -q 30,30 --poly-a --minimum-length 50:50 -u -5 -U -5 --trim-n $file1 $file2 > results/cutadapt/$case"_trimming_report.txt"


done < sample_list.txt

#Post-trimming Fastqc
echo "Generating Trimmed fastqc"
fastqc -o results/postrim_fastqc -f fastq results/trimmed_fastqs/*.gz


#align with STAR aligned
echo "Generating Alignment files"
while IFS= read -r line; do
    case=$(echo $line)
    echo "Aligning file $case"
    file1o="results/trimmed_fastqs/"$case".R1.trimmed_fastq.gz"
    file2o="results/trimmed_fastqs/"$case".R2.trimmed_fastq.gz"

    fileprefix="results/aligned_bams/"$case"_"
    STAR --runThreadN 1 --runMode alignReads --genomeDir $star_ref --readFilesIn $file1o $file2o --twopassMode Basic --sjdbGTFfile $anno_dir/gencode.v43.primary_assembly.annotation.chr22.gtf --quantMode TranscriptomeSAM GeneCounts --quantTranscriptomeBan IndelSoftclipSingleend --readFilesCommand zcat --outSAMtype BAM SortedByCoordinate  --outSAMunmapped Within --outSAMattributes Standard --outFileNamePrefix $fileprefix
	
done < sample_list.txt


#Generate RSEM counts 
echo "Generating RSEM files"
while IFS= read -r line; do
    case=$(echo $line)
    echo "Processing $case"

    bam="results/aligned_bams/"$case"_Aligned.toTranscriptome.out.bam"
    ref=$rsem_ref"/rsemref_GRCh38_chr22"
    prefix="results/rsem_outs/"$case".RSEM"
    log="results/rsem_outs/"$case".log"

    rsem-calculate-expression -p 1 --paired-end --alignments --estimate-rspd --calc-ci --seed 123 --no-bam-output --strandedness reverse $bam $ref $prefix > $log 

done < sample_list.txt

#prepare multiqc report
echo "preparing multiqc report"
cd results/multiqc
multiqc -v -f -c ../../code/multiqc_config.yaml ../

#merge rsem files
echo "Merging RSEM outputs"
cd ../
python /home/ec2-user/scripts/merge_rsem_results.py /home/ec2-user/data/genome_assembly_files/annotate.genes.txt /home/ec2-user/results/rsem_outs/ /home/ec2-user/results/rsem_outs/


echo "Job Finished"






