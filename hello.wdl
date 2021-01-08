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
        download_path_suffix = download_path_suffix
    }
    call test { 
      input: 
        file = download_curl.extracted_read
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
    String filename = basename(download_path_suffix)
    String dockerImage = "tutum/curl"
  }
  command <<<
    curl \
    -L \
    ftp://ftp.sra.ebi.ac.uk/~{download_path_suffix} -o ~{filename}
    gunzip -f ~{filename}
    >>>
  runtime {
    docker: dockerImage
  }
  output {
    File extracted_read = basename(filename, ".gz")
  }
}

task download_ascp {
  input { 
    String download_path_suffix
    String filename = basename(download_path_suffix)
    String dockerImage = "mitchac/asperacli"
  }
  command <<<
    ascp \
    -QT \ 
    -l 300m \ 
    -P33001 \
    -i /root/.aspera/cli/etc/asperaweb_id_dsa.openssh \  
    era-fasp@fasp.sra.ebi.ac.uk:~{download_path_suffix} \ 
    ~{filename}
    gunzip -f ~{filename}
    >>>
  runtime {
    docker: dockerImage
  }
  output {
    File extracted_read = basename(filename, ".gz")
  }
}

task test {
  input { 
    File? file
    String dockerImage = "ubuntu"
  } 
  command {
    cat ${file} >> out.txt
  }
  runtime {
    docker: dockerImage
  }
  output {
    File outfile = "out.txt"
  }
}

task extract_archive {
  input { 
    File? zipped_file
    String dockerImage = "ubuntu"
  } 
  command {
    gunzip -f ${zipped_file}
  }
  runtime {
    docker: dockerImage
  }
  output {
    #File extracted_file = basename(zipped_file, ".gz")
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


