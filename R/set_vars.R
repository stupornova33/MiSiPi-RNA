#' takes a gff file 
#' only output is hairpin plots
#' @param bed_file 
#' @param input_file a string
#' @param genome a string
#' @param min_read_count an integer
#' @param plot_output a string, "T" or "F"
#' @param path_to_RNAfold a string
#' @param pi_pal a string
#' @param si_pal a string
#' @param annotate_bed a string, "T" or "F"
#' @param gff_file a string
#' 
#' @return a list
#' @export


set_vars <- function(bed_file, input_file, genome, min_read_count, plot_output, path_to_RNAfold, pi_pal, si_pal, annotate_bed, gff_file = NULL){

  bam_obj <- OpenBamFile(input_file)
  bam_header <- Rsamtools::scanBamHeader(bam_obj)
  chr_name <- names(bam_header[['targets']])
  chr_length <- unname(bam_header[['targets']])
  bam_header <- V2 <- V3 <- NULL
  
  test_list <- utils::read.csv(bed_file, sep = "\t", header = FALSE)
  
  mut_table <- function(V1){
    result <- which(chr_name == V1)
    return(result)
  }
  
  test <- unlist(sapply(test_list$V1, mut_table))
  test_list <- test_list %>% dplyr::mutate(V2 = V2 + 1, V3 = V3 + 1)
  test_list <- test_list %>%
    dplyr::mutate(chromosome = test) %>%
    dplyr::mutate(length = chr_length[chromosome])
  
  length <- test_list$length
  
  chrom_name <- test_list$V1
  reg_start <- test_list$V2
  reg_stop <- test_list$V3
  length <- test_list$length
  chromosome <- unlist(unname(test_list$chromosome))
  var_list <- list(chom_name = chrom_name, reg_start = reg_start, reg_stop = reg_stop, length = length, chromosome = chromosome, 
                   plot_output = plot_output, path_to_RNAfold = path_to_RNAfold, min_read_count = min_read_count, 
                   genome= genome, input_file = input_file, bed_file = bed_file, pi_pal = pi_pal, si_pal = si_pal, 
                   annotate_bed = annotate_bed , gff_file = gff_file)
  return(var_list)
}
