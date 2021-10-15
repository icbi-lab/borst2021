#!/usr/bin/env nextflow

RES_DIR = params.resultsDir


process p01_process_data {
    def id = "01_process_counts"
    cpus = 8
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.1.0/vanderburg_scanpy.sif"
    cache 'lenient'
    publishDir "$RES_DIR/01_process_data", mode: params.publishDirMode

    input:
        // it would be better to include all input files explicitly.
        // However not that easy due to the fact that file identifier
        // is its parent folder.
        file 'data' from Channel.fromPath("data")
        file 'sample_sheet.csv' from Channel.fromPath("tables/vanderburg_01_samples.csv")
        file 'notebook.Rmd' from Channel.fromPath("analyses/${id}.Rmd")

    output:
        file "adata.h5ad" into process_data_adata, process_data_adata_2
        file "${id}.html" into process_data_html

    """
    execute_notebook.sh ${id} ${task.cpus} notebook.Rmd \\
       "-r sample_sheet sample_sheet.csv -r output_file adata.h5ad -r data_dir data -r n_cpus ${task.cpus}"
    """
}


process p02_filter_data {
    def id = "02_filter_data"
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.1.0/vanderburg_scanpy.sif"
    cpus = 8
    publishDir "$RES_DIR/$id", mode: params.publishDirMode

    input:
        file 'lib/*' from Channel.fromPath("lib/jupytertools.py")
        file 'tables/*' from Channel.fromPath(
            "tables/{mitochondrial_genes,biomart,ribosomal_genes}.tsv"
        ).collect()
        file 'notebook.Rmd' from Channel.fromPath("analyses/${id}.Rmd")
        file 'input_adata.h5ad' from process_data_adata

    output:
        file "adata.h5ad" into filter_data_adata_1, filter_data_adata_2
        file "${id}.html" into filter_data_html

    """
    execute_notebook.sh ${id} ${task.cpus} notebook.Rmd \\
       "-r input_file input_adata.h5ad -r output_file adata.h5ad -r table_dir tables"
    """
}

/**
 * Use the pre-computed doublets from the `tables` directory
 * that was generated using this process instead.
 * This process takes some time to run and is not numerically stable,
 * i.e. the result is slightly different every time.
 */

// process p02b_doublet_detection {
//     def id = "02b_doublet_detection"
//     conda "/home/sturm/.conda/envs/vanderburg_scanpy"
//     cpus = 8
//     clusterOptions '-V -S /bin/bash -l gpu=1 -q all.q'
//     publishDir "$RES_DIR/$id", mode: params.publishDirMode

//     input:
//         file "input_adata.h5ad" from filter_data_adata_1
//         file "model.json" from Channel.fromPath("tables/solo_model.json")

//     output:
//         file "out/is_doublet.npy" into doublet_detection_is_doublet
//         file "out/*.pdf"

//     """
//     export OPENBLAS_NUM_THREADS=${task.cpus}
//     export OMP_NUM_THREADS=${task.cpus}
//     export MKL_NUM_THREADS=${task.cpus}
//     export OMP_NUM_cpus=${task.cpus}
//     export MKL_NUM_cpus=${task.cpus}
//     export OPENBLAS_NUM_cpus=${task.cpus}
//     solo -o out -p model.json input_adata.h5ad
//     """
// }


process p03_normalize {
    def id = "03_normalize"
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.1.0/vanderburg_scanpy.sif"
    cpus = 8
    publishDir "$RES_DIR/$id", mode: params.publishDirMode

    input:
        file "is_doublet.npy" from Channel.fromPath("tables/is_doublet.npy")
        file 'lib/*' from Channel.fromPath("lib/{jupytertools,scio,scpp}.py").collect()
        file 'tables/*' from Channel.fromPath(
            "tables/{biomart.tsv,cell_cycle_regev.tsv,adata_pca.pkl.gz,summary*.txt,ribosomal_genes.tsv}"
        ).collect()
        file 'notebook.Rmd' from Channel.fromPath("analyses/${id}.Rmd")
        file 'input_adata.h5ad' from filter_data_adata_2
        file 'adata_unfiltered.h5ad' from  process_data_adata_2

    output:
        file "adata.h5ad" into correct_data_adata
        file "${id}.html" into correct_data_html
        file "quality_stats.csv" into correct_data_quality_stats

    """
    execute_notebook.sh ${id} ${task.cpus} notebook.Rmd \\
       "-r input_file input_adata.h5ad -r output_file adata.h5ad -r tables_dir tables -r doublet_file is_doublet.npy -r adata_unfiltered_file adata_unfiltered.h5ad -r output_file_stats quality_stats.csv"
    """
}


process p04_annotate_cell_types {
    def id = "04_annotate_cell_types"
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.1.0/vanderburg_scanpy.sif"
    cpus = 8
    publishDir "$RES_DIR/$id", mode: params.publishDirMode

    input:
        file 'lib/*' from Channel.fromPath("lib/jupytertools.py")
        file 'tables/*' from Channel.fromPath(
            "tables/cell_type_markers.csv"
        ).collect()
        file 'notebook.Rmd' from Channel.fromPath("analyses/${id}.Rmd")
        file 'input_adata.h5ad' from correct_data_adata

    output:
        file "adata.h5ad" into annotate_cell_types_adata
        file "${id}.html" into annotate_cell_types_html

    """
    execute_notebook.sh ${id} ${task.cpus} notebook.Rmd \\
       "-r input_file input_adata.h5ad -r output_file adata.h5ad -r table_dir tables"
    """

}


process p05_prepare_adata_t_nk {
    def id = "05_prepare_adata_nk_t"
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.1.0/vanderburg_scanpy.sif"
    cpus 1
    publishDir "$RES_DIR/$id", mode: params.publishDirMode

    input:
        file 'lib/*' from Channel.fromPath("lib/jupytertools.py")
        file 'tables/*' from Channel.fromPath(
            "tables/{cell_type_markers.csv,adata_pca*.pkl.gz}"
        ).collect()
        file 'notebook.Rmd' from Channel.fromPath("analyses/${id}.Rmd")
        file 'input_adata.h5ad' from annotate_cell_types_adata

    output:
        file "adata.h5ad" into prepare_adata_t_nk
        file "${id}.html" into prepare_adata_t_nk_html
    """
    execute_notebook.sh ${id} ${task.cpus} notebook.Rmd \\
       "-r input_file input_adata.h5ad -r output_file adata.h5ad -r table_dir tables -r cpus ${task.cpus} -r results_dir ."
    """
}


process p50_analysis_nkg2a {
    def id = "50_analysis_nkg2a"
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.1.0/vanderburg_edger.sif"
    cpus 1
    publishDir "$RES_DIR/$id", mode: params.publishDirMode

    input:
        file 'notebook.Rmd' from Channel.fromPath("analyses/${id}.Rmd")
        file 'input_adata.h5ad' from prepare_adata_t_nk

    output:
        file "${id}.zip" into nkg2a_figures
        file "${id}.html" into nkg2a_html
        file "*.rda" into nkg2a_de_analysis_rda
    """
    execute_notebook.sh ${id} ${task.cpus} notebook.Rmd \\
       "-r input_file input_adata.h5ad -r output_dir ."
    # use python, zip not available in container
    python -m zipfile -c ${id}.zip figures/*.pdf
    """
}

process p51_run_de_nkg2a {
    def id = "51_run_de_nkg2a"
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.2.0/vanderburg_edger.sif"
    publishDir "$RES_DIR/$id", mode: params.publishDirMode

    cpus 6

    input:
        file input_data from nkg2a_de_analysis_rda.flatten()

    output:
        file "${input_data}.res.tsv" into run_de_analysis_nkg2a_results
        file "${input_data}.res.xlsx" into run_de_analysis_nkg2a_results_xlsx

    """
    export OPENBLAS_NUM_THREADS=${task.cpus} OMP_NUM_THREADS=${task.cpus} \
            MKL_NUM_THREADS=${task.cpus} OMP_NUM_cpus=${task.cpus} \
            MKL_NUM_cpus=${task.cpus} OPENBLAS_NUM_cpus=${task.cpus} \
            MKL_THREADING_LAYER=GNU
    run_de.R ${input_data} ${input_data}.res.tsv \
        --cpus=${task.cpus} \
        --excel=${input_data}.res.xlsx
    """
}

process p52_analysis_nkg2a_de {
    def id = "52_analysis_nkg2a_de"
    container "https://github.com/icbi-lab/borst2021/releases/download/containers-0.1.0/vanderburg_de_results.v2.sif"
    publishDir "$RES_DIR/$id", mode: params.publishDirMode

    input:
        file 'notebook.Rmd' from Channel.fromPath("analyses/${id}.Rmd")
        file "*" from run_de_analysis_nkg2a_results_xlsx.collect()
        file "*" from run_de_analysis_nkg2a_results.collect()

    output:
        file "${id}.html" into nkg2a_de_analysis
        file "*.zip" into nkg2a_de_analysis_zip

    """
    reportsrender notebook.Rmd \
        ${id}.html \
        --cpus=${task.cpus} \
        --params="de_dir='.'"
    python -m zipfile -c ${id}.zip *.xlsx figures/*.pdf
    """
}


process deploy {
    publishDir "${params.deployDir}", mode: "copy"
    executor "local"

    input:
        file "input/*" from Channel.from().mix(
            process_data_html,
            filter_data_html,
            correct_data_html,
            correct_data_quality_stats,
            annotate_cell_types_html,
            prepare_adata_t_nk_html,
            nkg2a_html,
            nkg2a_figures,
            nkg2a_de_analysis,
            nkg2a_de_analysis_zip,
        ).collect()

    output:
        file "*.html"
        file "*.zip"
        file "*.csv"

    """
    cp input/*.{html,zip,csv} .
    """
}

