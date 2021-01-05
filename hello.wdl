version 1.0

workflow hello {
  input {
    #File inputFastq
    String SRA_accession_num
    #Array[String]+ outputPaths
  }
  call download { 
    input: 
      SRA_accession_num = SRA_accession_num
    }
  #call split { 
  #  input: 
  #    inputFastq = inputFastq,
  #    outputPaths=outputPaths 
  #  }
}

task download {
  input { 
    String SRA_accession_num
    String dockerImage = "mitchac/asperacli"
  }
  command <<<
    ascp \
    -QT \ 
    -l 300m \ 
    -P33001 \
    -i /root/.aspera/cli/etc/asperaweb_id_dsa.openssh \  
    era-fasp@fasp.sra.ebi.ac.uk:${SRA_accession_num} \ 
    ${SRA_accession_num}
    >>>
  runtime {
    docker: dockerImage
  }
  output {
    Array[File] fastq_file = glob("*.fastq.gz")
  }
}

task split {
  input { 
    File inputFastq
    Array[String]+ outputPaths
    String dockerImage = "quay.io/biocontainers/fastqsplitter:1.1.0--py37h516909a_1"
  }
  command <<<
    set -e
    for FILE in ~{sep=' ' outputPaths}
    do
       mkdir -p "$(dirname ${FILE})"
    done
    fastqsplitter \
    -i ~{inputFastq} \
    -o ~{sep=' -o ' outputPaths}
  >>>
  output {
    Array[File] chunks = outputPaths
  }
  runtime {
    docker: dockerImage
  }
}
