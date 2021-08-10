#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
params.samples = ['141', '143', '149', '160', '176', '182', '185', '188', '197', '205', '208', '211', '68']

process count_uniquely_mapped_reads {
    input:
    tuple val(id), path(bam)

    output:
    path("summary.txt")

    script:
    """
    echo $id,\$(samtools view -c -q 1 $bam) > summary.txt
    """
}

process count_all_reads {
    cpus 2

    input:
    tuple val(id), path(fastq)

    output:
    path("summary.txt")

    script:
    """
    echo $id,\$(zgrep "^@" $fastq | wc -l) > summary.txt
    """
}

workflow {
    count_all_reads(
        Channel.from(params.samples).map{
            it -> [it, file("/data/projects/2019/singleCellSeq/vanderBurg_Oropharyngeal_Cancer/fastq/*${it}_GEX/*R2*.fastq.gz", checkIfExists: true)]
        }
    ) | collectFile(storeDir: baseDir, name: 'summary_fastq_counts.txt')

    count_uniquely_mapped_reads(
        Channel.from(params.samples).map{
            it -> [it, file("/home/sturm/projects/2021/borst2021/data/cellranger/${it}_GEX/outs/possorted_genome_bam.bam", checkIfExists: true)]
        }
    ) | collectFile(storeDir: baseDir, name: 'summary_unique_files.txt')
}
