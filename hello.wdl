version 1.0

workflow hello {
  input {
    #File inputFastq
    String download_path_suffix
    String download_filename
    #Array[String]+ outputPaths
  }
  call download-curl { 
    input: 
      download_path_suffix = download_path_suffix,
      download_filename = download_filename
    }
  #call split { 
  #  input: 
  #    inputFastq = inputFastq,
  #    outputPaths=outputPaths 
  #  }
}

task download-ascp {
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

task download-curl {
  input { 
    String download_path_suffix
    String download_filename
    String dockerImage = "tutum/curl"
  }
  command <<<
    curl \
    -L \
    ftp://ftp.sra.ebi.ac.uk/${download_path_suffix} -o ${download_filename}
    >>>
  runtime {
    docker: dockerImage
  }
  output {
    File downloaded_file = glob("*.fastq.gz")
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
