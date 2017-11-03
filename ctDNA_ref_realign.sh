#! /bin/bash

#Input parameters for the job array, set for UGER

#$ -cwd
#$ -l h_rt=20:00:00
#$ -l h_vmem=12G
#$ -N job_name
#$ -t 1-54
#$ -t 4

#software dependencies

source /broad/software/scripts/useuse
reuse BWA
reuse BEDTools
reuse Samtools
reuse Picard-Tools
reuse Java-1.8

#set the root directory and the path to the fusion info input file

MY_ROOT=/path/to/root/directory
MY_FILE=$MY_ROOT/fusions_input_example.txt

#print the header in the batch output file
#printf "SAMPLE_ID\tFUSION_NAME\tBREAK_POINT\tFUSION_READS\tWT_READS\tFUSION_SEQ\tWT_SEQ\n" > $MY_ROOT/batch.ref_align.out.txt

FUSION=$(awk "NR==$SGE_TASK_ID" $MY_FILE)

#read input variables from fusions_input.txt
read var1 var2 var3 var4 var5 var6 <<< $FUSION
export SAMPLE=$var1
export FUSION_NAME=$var2
export BREAK_POINT_FUSION=$var3
export BREAK_POINT_WT=$var5
export FUSION_SEQ=$var4
export BAM_FILE=$var6

echo "here is  the fusion info " $SAMPLE $FUSION_NAME $BREAK_POINT $BAM_FILE

#Make a separate anaysis directory for each sample

MY_ANALYSIS=$MY_ROOT$SAMPLE
echo $MY_ANALYSIS
mkdir $MY_ANALYSIS
cd $MY_ANALYSIS

#make the fasta file for the reference, including the fusion sequence contig and hg19 as wild type 

printf ">"$SAMPLE"_"$FUSION_NAME"\n"$FUSION_SEQ"\n" > $MY_ANALYSIS/$SAMPLE_fusion.fasta
cat $MY_ANALYSIS/$SAMPLE_fusion.fasta $MY_ROOT/mod_ref.fasta > $SAMPLE.fasta
bwa index $MY_ANALYSIS/$SAMPLE.fasta

#Sort the input bam per read name
samtools sort -m 2G -n -o $MY_ANALYSIS/$SAMPLE_out_bam.qsort $BAM_FILE
echo "Sorted the bam file."

#Extract paired reads
bedtools bamtofastq -i $MY_ANALYSIS/$SAMPLE_out_bam.qsort -fq $MY_ANALYSIS/$SAMPLE.end1.fq -fq2 $MY_ANALYSIS/$SAMPLE.end2.fq 
echo "Extracted the reads from the bam."

#realignment
bwa mem -M -t 16 $MY_ANALYSIS/$SAMPLE.fasta $MY_ANALYSIS/$SAMPLE.end1.fq $MY_ANALYSIS/$SAMPLE.end2.fq > $MY_ANALYSIS/$SAMPLE.aln.sam
echo "Realigned the reads against the new reference."

#filter low mapping quality reads
samtools view -b -h -q 40 -o $MY_ANALYSIS/$SAMPLE.aln.bam $MY_ANALYSIS/$SAMPLE.aln.sam
echo "Filtered out low mapping quality reads."

#Sort and index the new bam file
samtools sort $MY_ANALYSIS/$SAMPLE.aln.bam > $MY_ANALYSIS/$SAMPLE.sorted.bam
samtools index $MY_ANALYSIS/$SAMPLE.sorted.bam
echo "Sorted and indexed the new bam."

#remove the sam file to save space
rm $MY_ANALYSIS/$SAMPLE.aln.sam

#Mark Duplicates
java -Xmx4g -XX:+UseSerialGC -jar /seq/software/picard-public/current/picard.jar MarkDuplicates I=$MY_ANALYSIS/$SAMPLE.sorted.bam O=$MY_ANALYSIS/$SAMPLE.deduped.bam M=$MY_ANALYSIS/$SAMPLE.dup_metrics.txt CREATE_INDEX=true REMOVE_DUPLICATES=true
echo "Removed duplicates."

#Remove soft clipped reads
samtools view -h $MY_ANALYSIS/$SAMPLE.deduped.bam | awk '{if($0 ~ /^@/ || $6 !~ /S/) {print $0}}'| samtools view -Sb - > $MY_ANALYSIS/$SAMPLE.deduped.declipped.bam
echo "Removed soft clipped reads."

#Sort and index again
samtools sort $MY_ANALYSIS/$SAMPLE.deduped.declipped.bam > $MY_ANALYSIS/$SAMPLE.deduped.declipped.sorted.bam
samtools index $MY_ANALYSIS/$SAMPLE.deduped.declipped.sorted.bam

#Count the reads in support of the fusion
 
FUSION_READS=$(samtools view -c $MY_ANALYSIS/$SAMPLE.deduped.declipped.sorted.bam $SAMPLE"_"$FUSION_NAME":"$BREAK_POINT_FUSION)
echo "The number of junction reads in support of the gene fusion in sample "$SAMPLE" is:"$FUSION_READS

#Count the wild type reads
WT_READS=$(samtools view -c $MY_ANALYSIS/$SAMPLE.deduped.declipped.sorted.bam $BREAK_POINT_WT)
echo "The number of wild type reads in sample "$SAMPLE" is "$WT_READS

#Print to sample output file
printf $SAMPLE"\t"$FUSION_NAME"\t"$BREAK_POINT"\t"$FUSION_READS"\t"$WT_READS"\n" > $SAMPLE.ref_align.out.txt

#Append sample output to batch output file
cat $SAMPLE.ref_align.out.txt >> $MY_ROOT/batch.ref_align.out.txt

#remove large files

#rm $MY_ANALYSIS/$SAMPLE.aln.sam
rm $MY_ANALYSIS/$SAMPLE.sorted.bam
rm $MY_ANALYSIS/$SAMPLE.deduped.declipped.bam
