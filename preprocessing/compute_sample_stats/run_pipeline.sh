#!/usr/bin/bash

nextflow run main.nf -profile icbi -w $(readlink -f /home/sturm/scratch/projects/2021/borst2021/work2) -resume
