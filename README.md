This script uses .fastq.gz RNA files for its processing using publicly available bioinformatic tools. It launches multiple processes (1 per sample) to the megacomputer queue. Modifications on default parameters (trimming conditions, mapping tool, reference database, ...) must be done INSIDE this code.

IMPORTANT!! An IDs file is required for the correct functioning of this pipeline.

PIPELINE:

0) **IDs file creation**: IDs file must be a **tabulation-separated .txt formatted file**, containing some basic information:

|ID      |Out_Names |Group1 |Group2 |
|--------|----------|-------|-------|
|ID-001  |Sample1   |Male   |Diet1  |
|ID-002  |Sample2   |Female |Diet1  |
|ID-003  |Sample3   |Male   |Diet2  |
|ID-004  |Sample4   |Female |Diet2  |
|...     |...       |...    |...    |

Important: Do **NOT** include **headers** in your IDs file.

- **IDs and output names**: IDs are the names of the .fastq files before processing. Output names are base names given to the files once trimmed for an easier handling. If names are not desired to be changed, use the same code for both columns.
- **Sample groups**: Depending on the number of grouping variables we manage, some changes must be done in the code:
  - If only one group factor is used: `export parmix=('awk '{print $n}' $inputFile')`
  - If 2 or more group factors are used: `export parmix=('awk '{print $n "_" $n+1 "_" $n+2}' $inputFile')`
  
  Being n the column position inside the IDs file.

1) **TRIMMING**: Trim Galore! software. This step can be included (trimming=true) or omitted (trimming=false). 3 processes:
- Illumina adapters trimming
- A-tail trimming
- T-tail trimming

2) **MAPPING**: Versus Sus scrofa 11.1 reference genome. 3 options available:
- mapping='HISAT2': .sam file generation.
- mapping='TOPHAT': .bam file generation.
- mapping='NONE': Mapping omitted.

3) **.BAM SORTING**: Convert .sam or .bam to .sorted.bam with 'samtools sort'. 3 options available:
- samtools='bam2bam': Convert .bam to .sorted.bam - used for TOPHAT output.
- samtools='sam2bam': Convert .sam to .sorted.bam - used for HISAT2 output.
- samtools='NONE': .bam sorting omitted.

4) **READ COUNT**: With HTSEQ-COUNT tool. Outputs gene and transcript counts files.

