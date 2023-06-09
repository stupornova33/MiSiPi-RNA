#' run_all function
#' run all modules of the package and store metrics for ML
#' @param chrom_name a string
#' @param reg_stop an integer
#' @param reg_start an integer
#' @param chromosome an integer representing the chromosome number
#' @param length an integer
#' @param input_file a string
#' @param genome_file a string
#' @param min_read_count an integer
#' @param si_pal a string
#' @param pi_pal a string
#' @param plot_output a string, "T" or "F"
#' @param path_to_RNAfold a string
#' @param bed_file a string
#' @return results

#' @export



new_run_all <- function(chrom_name, reg_start, reg_stop, chromosome, length, input_file, genome_file, min_read_count, si_pal, pi_pal, 
                        plot_output, path_to_RNAfold, bed_file){
  
  width <- pos <- start <- end <- NULL
  local_ml <- data.table::data.table(
    'locus_length' = numeric(1), 'unique_read_bias' = numeric(1), 'strand_bias' = numeric(1), 'perc_GC' = numeric(1), 
    'highest_size' = numeric(1), 'perc_first_nucT' = numeric(1), 'perc_A10' = numeric(1), 'highest_si_col' = numeric(1),
    'num_si_dicer_reads' = numeric(1), 'mirna_dicerz_plus' = numeric(1),
    'mirna_dicerz_minus' = numeric(1), 'highest_pi_col' = numeric(1), 
    'max_pi_count' = numeric(1), 'max_piz_overlap' = numeric(1), 'phasedz_plus' = numeric(1), 
    'phasedz26_plus' = numeric(1), 'pingpong_phasedz_minus' = numeric(1), 'pingpong_phasedz26_minus' = numeric(1),
    'hp_dicerz_plus' = numeric(1), 'hp_phasedz_plus' = numeric(1), 
    'hp_phasedcount_plus' = numeric(1), 'MFE' = numeric(1), 'hp_dicerz_minus' = numeric(1), 
    'hp_phasedz_minus' = numeric(1), 'hp_phasedcount_minus' = numeric(1))
  
  
  local_ml$locus_length <- reg_stop - reg_start
  prefix <- paste0(chrom_name, "_", reg_start, "-", reg_stop)
  ###############################
  # process bam input files
  
  if(!dir.exists('run_all/')) dir.create('run_all/')
  all_dir <- 'run_all/'
  
  if(!file.exists(paste0(all_dir, 'run_all_logfile.txt'))) file.create(paste0(all_dir, 'run_all_logfile.txt'))
  logfile <- paste0(all_dir, "run_all_logfile.txt")
  
  bam_obj <- OpenBamFile(input_file)
  bam_header <- Rsamtools::scanBamHeader(bam_obj)
  chr_name <- names(bam_header[['targets']])
  chr_length <- unname(bam_header[['targets']])
  bam_header <- NULL
  chromosome <- which(chr_name == chrom_name)
  
  cat(file = logfile, paste0("chrom_name: ", chrom_name, " reg_start: ", reg_start, " reg_stop: ", reg_stop, "\n"), append = TRUE)
  cat(file = logfile, "Filtering forward and reverse reads by length\n", append = TRUE)
  
  chromP <- getChrPlus(bam_obj, chrom_name, reg_start, reg_stop)
  chromM <- getChrMinus(bam_obj, chrom_name, reg_start, reg_stop)
  
  forward_dt <- data.table::setDT(makeBamDF(chromP)) %>%
    subset(width <= 32 & width >= 15) %>% 
    dplyr::mutate(start = pos, end = pos + width - 1) %>% 
    dplyr::select(-c(pos))
  
  reverse_dt <- data.table::setDT(makeBamDF(chromM)) %>%
    subset(width <= 32 & width >= 15) %>%
    dplyr::mutate(start = pos, end = pos + width - 1) %>% 
    dplyr::select(-c(pos))
  
  if(nrow(forward_dt) == 0 && nrow(reverse_dt) == 0) return()
  
  total_read_count <- nrow(forward_dt) + nrow(reverse_dt)
  
  unique_read_count <- nrow(forward_dt %>% dplyr::distinct(start, end)) + nrow(reverse_dt %>% dplyr::distinct(start,end))
  
  local_ml$unique_read_bias <- unique_read_count/total_read_count
  
  chromP <- NULL
  chromM <- NULL
  ###############################
  # get extra metrics for ML
  
  perc_plus <- nrow(forward_dt)/(nrow(forward_dt) + nrow(reverse_dt))
  perc_minus <- nrow(reverse_dt)/(nrow(reverse_dt) + nrow(forward_dt))
  
  #combine perc minus and perc plus into "strand bias"
  
  if(perc_plus > perc_minus){
     local_ml$strand_bias <- perc_plus
  } else {
     local_ml$strand_bias <- perc_minus
  }
  
  local_ml$perc_GC <- get_GC_content(forward_dt, reverse_dt)
  read_dist <- get_read_dist(forward_dt, reverse_dt)
  
  max_size <- highest_sizes(read_dist)

  local_ml$highest_size <- max_size
  
  cat(file = logfile, "Creating size plots\n", append = TRUE)
  
  if(!dir.exists('run_all/size_plots/')) dir.create('run_all/size_plots/')
  
  if(plot_output == 'T'){
    size_dir <- 'run_all/size_plots/'
    size_plots <- plot_sizes(read_dist)
  }
  
  local_ml$perc_first_nucT <- first_nuc_T(forward_dt, reverse_dt)
  local_ml$perc_A10 <- get_nuc_10(forward_dt, reverse_dt)
  
  max_sizes <- NULL
  read_dist <- NULL
  ###############################
  # run siRNA function
  cat(file = logfile, "Begin siRNA function\n", append = TRUE)
  if(!dir.exists('run_all/siRNA_dir/')) dir.create('run_all/siRNA_dir/')
  
  si_dir <- 'run_all/siRNA_dir/'
  si_log <- file.create('si_logfile.txt')
 
  si_res <- siRNA_function(chrom_name, reg_start, reg_stop, length, min_read_count, genome_file, input_file, si_log, si_dir, si_pal, plot_output, path_to_RNAfold)
  print(si_res[[1]])
  max_si_heat <- get_max_si_heat(si_res)

  local_ml$highest_si_col <- max_si_heat$highest_si_col
 
  local_ml$num_si_dicer_reads <- si_res[[2]]$proper_count[5]/total_read_count
  
  si_res <- NULL
  max_si_heat <- NULL
  ###############################
  # run miRNA function
  cat(file = logfile, "Begin miRNA function\n", append = TRUE)
  if(!dir.exists('run_all/miRNA_dir/')) dir.create('run_all/miRNA_dir/')
  miRNA_dir <- 'run_all/miRNA_dir/'
  mi_log <- file.create(paste0(miRNA_dir, 'mi_logfile.txt'))
  mi_res <- miRNA_function(chrom_name, reg_start, reg_stop, chromosome, length, "+", min_read_count, genome_file, input_file, mi_log, miRNA_dir, plot_output, path_to_RNAfold)
  mirnaMFE_plus <- mi_res[[1]][1]
  #local_ml$mirna_dicer_plus <- mi_res[[1]]$shift[5]
  #local_ml$mirna_maxcount_plus <- mi_res[[1]]$proper_count[5]/total_read_count
  local_ml$mirna_dicerz_plus <- mi_res[[2]]$zscore[5]
  
  mi_res <- miRNA_function(chrom_name, reg_start, reg_stop, chromosome, length, "-", min_read_count, genome_file, input_file, mi_log, miRNA_dir, plot_output, path_to_RNAfold)
  mirnaMFE_minus <- mi_res[[1]][1]
  local_ml$mirna_dicerz_minus <- mi_res[[2]]$zscore[5]
  #local_ml$mirna_dicer_minus <- mi_res[[1]]$shift[5]
  #local_ml$mirna_maxcount_minus <- mi_res[[1]]$proper_count[5]/total_read_count
  
  
  ################################
  # run piRNA function
  cat(file = logfile, "Begin piRNA function\n", append = TRUE)
  if(!dir.exists('run_all/piRNA_dir/')) dir.create('run_all/piRNA_dir/')
  
  piRNA_dir <- 'run_all/piRNA_dir/'
  pi_log <- file.create(paste0(piRNA_dir, 'pi_logfile.txt'))
  pi_res <- piRNA_function(chrom_name, reg_start, reg_stop, input_file, pi_log, piRNA_dir, pi_pal, plot_output = "F")
  
  if(!sum(pi_res[[1]]) == 0){
    max_pi_heat <- get_max_pi_heat(pi_res)

    local_ml$highest_pi_col <- max_pi_heat$highest_pi_col

    local_ml$max_pi_count <- max_pi_heat$highest_pi_count/total_read_count

    local_ml$max_piz_overlap <- get_max_zscore(unlist(pi_res[[2]]$Z_score), unlist(pi_res[[2]]$Overlap))[[1]]
  } else {
 
    local_ml$highest_pi_col <- NA
 
    local_ml$max_pi_count <- NA

    local_ml$max_piz_overlap <- NA
  }
  
  pi_res <- NULL
  max_pi_heat <- NULL
  ###############################                      
  # run phased_piRNA function
  cat(file = logfile, "Begin phased_piRNA function\n", append = TRUE)
  
  if(!dir.exists('run_all/phased_dir/')) dir.create('run_all/phased_dir/')
  phased_dir <- 'run_all/phased_dir/'
  phased_log <- file.create(paste0(phased_dir, 'phased_logfile.txt'))
  phased_res <- phased_piRNA_function("+", chrom_name, reg_start, reg_stop, input_file, phased_log, phased_dir, plot_output= "F")
  
  local_ml$phasedz_plus <- phased_res[1]

  local_ml$phasedz26_plus <- phased_res[2]
 
  phased_res <- phased_piRNA_function("-", chrom_name, reg_start, reg_stop, input_file, phased_log, phased_dir, plot_output= "F")
  
  local_ml$pingpong_phasedz_minus <- phased_res[1]
  local_ml$pingpong_phasedz26_minus <- phased_res[2]
  ####################################################################
  # run hairpin function
  
  cat(file = logfile, "Begin hairpin function\n", append = TRUE)
  if(!dir.exists('run_all/hairpin_plots/')) dir.create('run_all/hairpin_plots/')
  hairpin_dir <- 'run_all/hairpin_plots/'
  hairpin_log <- file.create(paste0(hairpin_dir, 'hairpin_log.txt'))
  
  hp_res <- hairpin_function(chrom_name, reg_start, reg_stop, "+", length,
                                        min_read_count, genome_file, input_file, hairpin_log, hairpin_dir, plot_output, path_to_RNAfold)
  
  hpMFE_plus <- hp_res[[1]]
  local_ml$hp_dicerz_plus <- hp_res[[2]]$zscore[5]
  local_ml$hp_phasedz_plus <- hp_res[[4]]
  local_ml$hp_phasedcount_plus <- hp_res[[3]]
  
  hp_res <- hairpin_function(chrom_name, reg_start, reg_stop, "-", length,
                                         min_read_count, genome_file, input_file, hairpin_log, hairpin_dir, plot_output, path_to_RNAfold)
  hpMFE_minus <- hp_res[[1]]
  local_ml$hp_dicerz_minus <- hp_res[[2]]$zscore[5]
  local_ml$hp_phasedz_minus <- hp_res[[4]]
  local_ml$hp_phasedcount_minus <- hp_res[[3]]
  
  all_mfe <- c(unlist(unname(mirnaMFE_minus)), unlist(unname(mirnaMFE_plus)), hpMFE_minus, hpMFE_plus)
  min_mfe <- min(all_mfe)
  local_ml$MFE <- min_mfe
     
  ####################################################################
  # add results to table
  tbl_name <- strsplit(bed_file, "[.]")[[1]][1]
  df <- as.matrix(local_ml)
  
  if(ncol(local_ml) < 27){
      print('HALT!!!!!!!!!!!!!!!!!')
      print(paste0('chrom_name: ', chrom_name, ' reg_start: ', reg_start, ' reg_stop: ', reg_stop))
  }
  
  cat(file = logfile, "Writing results to table\n", append = TRUE)
  if(!file.exists(paste0(tbl_name, "_ml.txt"))){
    utils::write.table(df, file = paste0(tbl_name, "_ml.txt"), sep = "\t", quote = FALSE, append = T, col.names = T, na = "NA", row.names = F)
  } else {
    utils::write.table(df, file = paste0(tbl_name, "_ml.txt"), quote = FALSE, sep = "\t", col.names = F, append = TRUE, na = "NA", row.names = F)
  }
  
}
