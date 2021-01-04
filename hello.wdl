version 1.0

workflow hello {
  input {
    File inputFastq
    Array[String]+ outputPaths
  }
  call split { 
  input: inputFastq = inputFastq,
  outputPaths=outputPaths 
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
