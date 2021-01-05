version 1.0

workflow hello {
  input {
    String SRA_accession_num
  }
  call get_reads_from_run { 
    input: 
      SRA_accession_num = SRA_accession_num
    }
  scatter(download_path_suffix in get_reads_from_run.download_path_suffixes) {
    call download_curl { 
      input: 
        download_path_suffixes = download_path_suffix
      }
  }  
}

task get_reads_from_run {
  input { 
    String SRA_accession_num
    String dockerImage = "tutum/curl"
  }
  command <<<
    curl -k 'https://www.ebi.ac.uk/ena/portal/api/filereport?accession=~{SRA_accession_num}&result=read_run&fields=fastq_ftp' \
    | grep -Po 'vol.*?fastq.gz' \
    > ftp.txt
  >>>
  output {
    Array[String] download_path_suffixes = read_lines("ftp.txt")
  }
  runtime {
    docker: dockerImage
  }
}

task download_curl {
  input { 
    String download_path_suffix
    String dockerImage = "tutum/curl"
  }
  command <<<
    curl \
    -L \
    ftp://ftp.sra.ebi.ac.uk/~{download_path_suffix} -o ~{basename(download_path_suffix)}
    >>>
  runtime {
    docker: dockerImage
  }
  output {
    File zipped_read = glob("*.fastq.gz")
  }
}

task download_ascp {
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


