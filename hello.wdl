version 1.0

workflow hello {
  input {
    String SRA_accession_num
    #File inputFastq
    #String download_path_suffix
    #String download_filename
    #Array[String]+ outputPaths
  }
  call get_reads_from_run { 
    input: 
      SRA_accession_num = SRA_accession_num
    }
  #call download_curl { 
  #  input: 
  #    download_path_suffix = download_path_suffix,
  #    download_filename = download_filename
  #  }
  #call split { 
  #  input: 
  #    inputFastq = inputFastq,
  #    outputPaths=outputPaths 
  #  }
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

task download_curl {
  input { 
    String download_path_suffix
    String download_filename
    String dockerImage = "tutum/curl"
  }
  command <<<
    curl \
    -L \
    ftp://ftp.sra.ebi.ac.uk/~{download_path_suffix} -o ~{download_filename}
    >>>
  runtime {
    docker: dockerImage
  }
  output {
    File downloaded_file = download_filename
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

task get_reads_from_run {
  input { 
    String SRA_accession_num
    String dockerImage = "tutum/curl"
  }
  command <<<
    curl -k 'https://www.ebi.ac.uk/ena/portal/api/filereport?accession=~{SRA_accession_num}&result=read_run&fields=fastq_ftp' \
    | grep -Po 'vol.*?fastq.gz' \
    > ftp.txt
    curl -L -k 'http://www.ebi.ac.uk/ena/portal/api/filereport?accession=~{SRA_accession_num}&result=read_run&fields=fastq_bytes' \
    | grep -Po '[0-9]*' | sed -n '1!p' \
    > bytes.txt
    paste -d, ftp.txt bytes.txt > out.txt
  >>>
  output {
    File read_list = out.txt
  }
  runtime {
    docker: dockerImage
  }
}
