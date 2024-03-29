#!/bin/bash
#SBATCH -t 00:20:00
#SBATCH --partition=thinnodes,cola-corta
#SBATCH -J RNASEQ1

usage(){
cat << _EUs_
$(basename "$0") -- Initiates a pipeline for RNAseq analysis.\n
\nDESCRIPTION:\n
	\tThis script uses .fastq.gz RNA files for its processing using publicly available bioinformatic tools. It launches multiple processes\n
	\t(1 per sample) to the megacomputer queue.\n
	\tModifications on default parameters (trimming conditions, mapping tool, reference database, ...) must be done INSIDE this code.\n
	\tIMPORTANT!! An IDs file is required for the correct functioning of this pipeline.\n
\nPIPELINE:\n
	\tA) TRIMMING: Trim Galore! software. This step can be included (trimming=true) or omitted (trimming=false). 3 processes:\n
		\t\t- Illumina adapters trimming\n
		\t\t- A-tail trimming\n
		\t\t- T-tail trimming\n
	\n\tB) MAPPING: Versus Sus scrofa 11.1 reference genome. 3 options available:\n
		\t\t- mapping='TOPHAT': .bam file generation.\n
		\t\t- mapping='HISAT2': .sam file generation.\n
		\t\t- mapping='NONE': Mapping omitted.\n
	\n\tC) .BAM FILE: Convert .sam or .bam to .sorted.bam with 'samtools sort'. 3 options available:\n
		\t\t- samtools='bam2bam': Convert .bam to .sorted.bam - used for TOPHAT output.\n
		\t\t- samtools='sam2bam': Convert .sam to .sorted.bam - used for HISAT2 output.\n
		\t\t- samtools='NONE': .bam sorting omitted.\n
	\n\tD) READ COUNT: With HTSEQ-COUNT tool. Outputs gene and transcript counts files.\n 
\nPARAMETERS:\n
	\t-h, --help: Prints this screen.\n
_EUs_
}

# SCRIPT RUN OPTIONS
####################################################################
OPTS=`getopt -o h --long help -- "$@"`
eval set -- "$OPTS"

while true; do
	case $1 in
		-h | --help)
			echo -e $(usage) | less ; exit ;;
		--) shift ; break ;;
        *) echo "Script definition error! Seems that one or more parameters are not valid..." ; exit 1 ;;
	esac
done

# VARIABLE ASSIGNMENT
####################################################################
export INPUT=$LUSTRE/Results/RNAseq/ovilo9/RawData
export PTH=$LUSTRE/Results/RNAseq/ovilotest
export inputFile=$PTH/IDs_all.txt
export GTF=$LUSTRE/genoma-referencia_ss11/Sus_scrofa.Sscrofa11.1.90.gtf
export HISAT2_TRANS=$LUSTRE/genoma-referencia_ss11/INDEX_ht2/SS11-INDEX
#export GTF=/home/ovilo/winpro/I3-NGS-INIA/Tools/hisat2-2.1.0/genome_trans_index/ensembl_Sscrofa11.1.91/Sus_scrofa.Sscrofa11.1.91.gtf

# PARAMETERS
####################################################################
export trimming=false
export mapping='HISAT2'
export samtools='sam2bam'
export htseq=true

export lines=`wc -l $inputFile | awk -F ' ' '{print $1}'`
export prenames=(`awk '{print $1}' $inputFile`)
export names=(`awk '{print $2}' $inputFile`)
export parmix=(`awk '{print $3}' $inputFile`)
#export parmix=(`awk '{print $3 "_" $4}' $inputFile`)

echo 'Number of animals to analyse = '$lines

# DIRECTORY CREATION
####################################################################
if [ ! -d $PTH/RawData/ ]; then mkdir -p $PTH/RawData/; fi

if [ "$trimming" = true ]; then
	if [ ! -d $PTH/1_adapter_trimmed/ ]; then mkdir -p $PTH/1_adapter_trimmed/; fi
	if [ ! -d $PTH/2_A_tail_trimmed/ ]; then mkdir -p $PTH/2_A_tail_trimmed/; fi
	if [ ! -d $PTH/3_T_tail_trimmed/ ]; then mkdir -p $PTH/3_T_tail_trimmed/; fi
elif [ "$trimming" = false ]; then
	:
else
	echo "ERROR: trimming value not valid. Please choose booleans: true or false"
	exit 1
fi
	
if [ "$mapping" = 'TOPHAT' ]; then
	if [ ! -d $PTH/4_tophat/ ]; then mkdir $PTH/4_tophat/; fi
elif [ "$mapping" = 'HISAT2' ]; then
	if [ ! -d $PTH/4_hisat2/ ]; then mkdir $PTH/4_hisat2/; fi
elif [ "$mapping" = 'NONE' ]; then
	:
else
	echo "ERROR: mapping value not valid. Please choose 'TOPHAT', 'HISAT2' or 'NONE'"
	exit 1
fi

if [ "$samtools" == "bam2bam" ] || [ "$samtools" == "sam2bam" ]; then
	if [ ! -d $PTH/5_BAM/ ]; then mkdir -p $PTH/5_BAM/; fi
	export BAM=$PTH/5_BAM
elif [ "$samtools" == 'NONE' ]; then
	:
else
	echo "ERROR: samtools value not valid. Please choose 'bam2bam', 'sam2bam' or 'NONE'"
	exit 1
fi

if [ ! -d $PTH/6_HTSEQC/ ]; then mkdir -p $PTH/6_HTSEQC/; fi
export COUNT=$PTH/6_HTSEQC

# PIPELINE
####################################################################
for i in `seq $lines`; do
	sbatch ~/bin/RNAseq/htseq.sh $trimming $mapping $samtools $htseq ${prenames[$i-1]} ${names[$i-1]} ${parmix[$i-1]}
done

# AFTER GETTING ALL Htseq-Count FILES:
#module load cesga/2018 gcc/6.4.0 R/3.5.1
#Rscript ~/bin/RNAseq/R_processing.sh $PTH

# FINAL CODE
####################################################################
# Calculate total size of folders in $PTH:
#du -sh --total $PTH/*
