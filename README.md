# peds_ctDNA
We have created a custom algorithm for quantifying the number of translocation reads and wild-type reads in plasma samples with detectable ctDNA and predetermined gene fusions.
The main script ctDNA_ref_realign.sh is written as a job array, specifically for submitting to UGER (Univa Grid Engine). It is also dependant on several resources available at 
the Broad Institute, including Sam Tools, BWA, Picard Tools and BED Tools. It takes two input files, one supplying the information about the gene fusions previously detected and 
the other one is just the human genome reference sequence with simplified contig names. You can find an example of the fusions info input file here - fusions_info_example.txt. 
The column descriptions are following: SAMPLE_ID[STRING], FUSION_NAME[STRING], BREAK_POINT_FUSION[RANGE], FUSION_SEQUENCE[STRING], BREAK_POINT_WT[RANGE], BAM_PATH[STRING].
The script generates an output file per sample named SAMPLE_NAME.ref_align.out.txt with the following columns: SAMPLE_ID[STRING], FUSION_NAME[STRING], NUM_FUSION_READS[INT], 
NUM_WT_READS[INT]. It also generates batch.ref_align.out.txt with output data for all the samples in the job array.
For more information, contact Alma Imamovic (imamovic@broadinstitute.org).     
