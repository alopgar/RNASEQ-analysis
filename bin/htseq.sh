#!/bin/bash
#SBATCH -t 20:00:00
#SBATCH --partition=thinnodes,cola-corta
#SBATCH -N 1      #solicita un modulo
#SBATCH -n 1      #numero de tareas
#SBATCH -c 24     #Numero de procesadores por tarea
#SBATCH -J HTSEQ     #nombre del proceso

module load gcc/6.4.0 samtools/1.9 htseq/0.10.0-python-2.7.15

prename=$4
name=$5
params=$6

# TRIM GALORE (need process time)
####################################################################
# Install TrimGalore:
# ...
if [ "$1" = true ]; then
	module load cutadapt/1.18-python-2.7.15
	echo 'Trimming sample '$prename' And changing name to '$name' with parameters: '$params
	## Copy RawData
	find $INPUT -name $prename*'.fastq.gz' | xargs cp -t $PTH/RawData/
	## Trimming 1: Delete Illumina adapters.
	# Also rename files ($prename to $name) and join Fw and Rv reports.
	$STORE/ENVS/TrimGalore-0.4.3/trim_galore -q 20 --paired --stringency 6 --length 40 -a AGATCGGAAGA -a2 AGATCGGAAGA -o $PTH/1_adapter_trimmed/ $PTH/RawData/$prename'_1.fastq.gz' $PTH/RawData/$prename'_2.fastq.gz'
	mv $PTH/1_adapter_trimmed/$prename'_1_val_1.fq.gz' $PTH/1_adapter_trimmed/$name'_1.fq.gz'
	mv $PTH/1_adapter_trimmed/$prename'_2_val_2.fq.gz' $PTH/1_adapter_trimmed/$name'_2.fq.gz'
	cat $PTH/1_adapter_trimmed/$prename'_1.fastq.gz_trimming_report.txt' $PTH/1_adapter_trimmed/$prename'_2.fastq.gz_trimming_report.txt' > $PTH/1_adapter_trimmed/$prename'_trimming_report.txt'
	rm $PTH/1_adapter_trimmed/$prename'_1.fastq.gz_trimming_report.txt' $PTH/1_adapter_trimmed/$prename'_2.fastq.gz_trimming_report.txt'
	## Trimming 2: Delete poly-A tails.
	# Also rename files (_1_val_ to _pA_) and join Fw and Rv reports.
	$STORE/ENVS/TrimGalore-0.4.3/trim_galore -q 20 --paired --stringency 6 --length 40 -a AAAAAAAAAAAAA -a2 AAAAAAAAAAAAA -o $PTH/2_A_tail_trimmed/ $PTH/1_adapter_trimmed/$name'_1.fq.gz' $PTH/1_adapter_trimmed/$name'_2.fq.gz' 
	rename '_1_val_1' '_pA_1' $PTH/2_A_tail_trimmed/$name*
	rename '_2_val_2' '_pA_2' $PTH/2_A_tail_trimmed/$name*
	cat $PTH/2_A_tail_trimmed/$name'_1.fq.gz_trimming_report.txt' $PTH/2_A_tail_trimmed/$name'_2.fq.gz_trimming_report.txt' > $PTH/2_A_tail_trimmed/$name'_pA_trimming_report.txt'
	rm $PTH/2_A_tail_trimmed/$name'_1.fq.gz_trimming_report.txt' $PTH/2_A_tail_trimmed/$name'_2.fq.gz_trimming_report.txt'
	## Trimming 3: Delete ploy-T tails.
	# Also rename files (_pA_1_val_1 to 1_final) and join Fw and Rv reports.
	$STORE/ENVS/TrimGalore-0.4.3/trim_galore -q 20 --paired --stringency 6 --length 40 --fastqc -a TTTTTTTTTTTTT -a2 TTTTTTTTTTTTT -o $PTH/3_T_tail_trimmed/ $PTH/2_A_tail_trimmed/$name'_pA_1.fq.gz' $PTH/2_A_tail_trimmed/$name'_pA_2.fq.gz'
	rename '_pA_1_val_1' '_1_final' $PTH/3_T_tail_trimmed/$name*
	rename '_pA_2_val_2' '_2_final' $PTH/3_T_tail_trimmed/$name*
	cat $PTH/3_T_tail_trimmed/$name'_pA_1.fq.gz_trimming_report.txt' $PTH/3_T_tail_trimmed/$name'_pA_2.fq.gz_trimming_report.txt' > $PTH/3_T_tail_trimmed/$name'_pT_trimming_report.txt'
	rm $PTH/3_T_tail_trimmed/$name'_pA_1.fq.gz_trimming_report.txt' $PTH/3_T_tail_trimmed/$name'_pA_2.fq.gz_trimming_report.txt'
fi

# MAPPING (need process time)
####################################################################
# Choice between TOPHAT and HISAT2:
if [ "$2" = 'TOPHAT' ]; then
	echo 'TOPHAT: MAPPING trimmed sample '$name' with parameters: '$params
	module load tophat/2.1.1
	# Sample directory
	if [ ! -d $PTH/4_tophat/tophat_$name/ ]; then mkdir -p $PTH/4_tophat/tophat_$name/; fi
	# Tophat pipeline
	tophat --library-type fr-firststrand -r 100 -p 12 -G $LUSTRE/genoma-referencia_ss11/Sus_scrofa.Sscrofa11.1.90.gtf \
		-o $PTH/4_tophat/tophat_$name $LUSTRE/genoma-referencia_ss11/Ss11IND $PTH/3_T_tail_trimmed/$name'_1_final.fq.gz' $PTH/3_T_tail_trimmed/$name'_2_final.fq.gz'
elif [ "$2" = 'HISAT2' ]; then
	echo 'HISAT2: MAPPING trimmed sample '$name' with parameters: '$params
	module load intel/2018.3.222 hisat2/2.1.0
	# R1/R2 variables
	R1=$name'_1_final.fq.gz'
	R2=$name'_2_final.fq.gz'
	echo "FORWARD:"$R1
	echo "REVERSE:"$R2
	# Hisat2 pipeline
	hisat2 -q -p 4 --fr --rna-strandness RF -x $HISAT2_TRANS -1 $PTH/3_T_tail_trimmed/$R1 -2 $PTH/3_T_tail_trimmed/$R2 -S $PTH/4_hisat2/$name.sam 2> $PTH/4_hisat2/$name.summary.txt
elif [ "$2" = 'NONE' ]; then
	echo 'MAPPING NOT REQUESTED for sample '$name' with parameters: '$params
fi

# SAMTOOLS: (30')
####################################################################
if [ "$3" = true ]; then
	if [ "$2" = 'TOPHAT' ]; then
 		# .bam to sorted.bam: (30 min)
		samtools sort -n -o $BAM/$name.n.sorted.bam $PTH/4_tophat/tophat_$name/accepted_hits.bam
	elif [ "$2" = 'HISAT2' ]; then
 		# .sam to sorted.bam: (30 min)
		samtools sort -n -o $BAM/$name.n.sorted.bam $PTH/4_hisat2/$name.sam
	fi
fi

# Htseq-Count: (1h 30' + 2h 30')
####################################################################
htseq-count -f bam -r name --stranded=reverse -t exon -i gene_id -m union $BAM/$name.n.sorted.bam $GTF > $COUNT/$name.GnCount.txt
htseq-count -f bam -r name --stranded=reverse -t exon -i transcript_id -m union $BAM/$name.n.sorted.bam $GTF > $COUNT/$name.TrCount.txt

#--stranded=reverse !!! DO NOT use "--stranded=yes" for illumina truseq stranded libraries  -> did not count correctly 
# --nonunique=<nonunique mode>
# Mode to handle reads that align to or are assigned to more than one feature in the overlap <mode> of choice (see -m option). <nonunique mode> are none and all (default: none)
