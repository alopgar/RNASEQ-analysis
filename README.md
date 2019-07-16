This script uses .fastq.gz RNA files for its processing using publicly available bioinformatic tools. It launches multiple processes (1 per sample) to the megacomputer queue.
Modifications on default parameters (trimming conditions, mapping tool, reference database, ...) must be done INSIDE this code.
IMPORTANT!! An IDs file is required for the correct functioning of this pipeline.

PIPELINE:

A) TRIMMING: Trim Galore! software. This step can be included (trimming=true) or omitted (trimming=false). 3 processes:
- Illumina adapters trimming
- A-tail trimming
- T-tail trimming

B) MAPPING: Versus Sus scrofa 11.1 reference genome. 3 options available:
- mapping='TOPHAT': .bam file generation. Also processed with 'samtools sort'.
- mapping='HISAT2': .sam file generation. Converted to .bam with 'samtools sort'.
- mapping='NONE': Mapping omitted.

C) READ COUNT: With HTSEQ-COUNT tool. Outputs gene and transcript counts files.
