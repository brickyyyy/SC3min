#' Run all steps of \code{sc3min} in one go
#' 
#' This function is a wrapper that executes all steps of \code{sc3min} analysis in one go.
#' 
#' @param object an object of \code{SingleCellExperiment} class.
#' @param ks a range of the number of clusters \code{k} used for \code{sc3min} clustering.
#' Can also be a single integer.
#' @param gene_filter a boolen variable which defines whether to perform gene 
#' filtering before sc3min clustering.
#' @param pct_dropout_min if \code{gene_filter = TRUE}, then genes with percent of dropouts smaller than 
#' \code{pct_dropout_min} are filtered out before clustering.
#' @param pct_dropout_max if \code{gene_filter = TRUE}, then genes with percent of dropouts larger than 
#' \code{pct_dropout_max} are filtered out before clustering.
#' @param d_region_min defines the minimum number of eigenvectors used for 
#' kmeans clustering as a fraction of the total number of cells. Default is \code{0.04}.
#' See \code{sc3min} paper for more details.
#' @param d_region_max defines the maximum number of eigenvectors used for 
#' kmeans clustering as a fraction of the total number of cells. Default is \code{0.07}.
#' See \code{sc3min} paper for more details.
#' @param svm_num_cells number of randomly selected training cells to be used 
#' for SVM prediction. The default is \code{NULL}.
#' @param svm_train_inds a numeric vector defining indeces of training cells 
#' that should be used for SVM training. The default is \code{NULL}.
#' @param svm_max define the maximum number of cells below which SVM is not run.
#' @param n_cores defines the number of cores to be used on the user's machine. If not set, `sc3min` will use all but one cores of your machine.
#' @param kmeans_nstart nstart parameter passed to \code{\link[stats]{kmeans}} function. Can be set manually. By default it is 
#' \code{1000} for up to \code{2000} cells and \code{50} for more than \code{2000} cells.
#' @param kmeans_iter_max iter.max parameter passed to \code{\link[stats]{kmeans}} 
#' function.
#' @param k_estimator boolean parameter, defines whether to estimate an optimal number of clusters \code{k}. If user has already defined the ks parameter the estimation does not affect the user's paramater.
#' @param biology boolean parameter, defines whether to compute differentially expressed genes, marker 
#' genes and cell outliers.
#' @param rand_seed sets the seed of the random number generator. \code{sc3min} is a stochastic
#' method, so setting the \code{rand_seed} to a fixed values can be used for reproducibility
#' purposes.
#' 
#' @name sc3min
#' @aliases sc3min
#' 
#' @return an object of \code{SingleCellExperiment} class
sc3min.SingleCellExperiment <- function(object, ks, gene_filter, pct_dropout_min, pct_dropout_max, d_region_min, 
                                        d_region_max, svm_num_cells, svm_train_inds, svm_max, n_cores, kmeans_nstart, kmeans_iter_max, 
                                        k_estimator, biology, rand_seed) {
  object <- sc3min_prepare(object, gene_filter, pct_dropout_min, pct_dropout_max, 
                           d_region_min, d_region_max, svm_num_cells, svm_train_inds, svm_max, n_cores, kmeans_nstart, 
                           kmeans_iter_max, rand_seed)
  if (k_estimator) {
    object <- sc3min_estimate_k(object)
    # Do not override cluster if user has set a k
    if (is.null(ks))
    {
      ks <- metadata(object)$sc3min$k_estimation
    }
  }
  object <- sc3min_calc_dists(object)
  object <- sc3min_calc_transfs(object)
  object <- sc3min_kmeans(object, ks)
  object <- sc3min_calc_consens(object)
  if (biology) {
    object <- sc3min_calc_biology(object, ks)
  }
  return(object)
}

#' @rdname sc3min
#' @aliases sc3min
setMethod("sc3min", signature(object = "SingleCellExperiment"), sc3min.SingleCellExperiment)

#' Prepare the \code{SingleCellExperiment} object for \code{sc3min} clustering.
#' 
#' This function prepares an object of \code{SingleCellExperiment} class for \code{sc3min} clustering. It
#' creates and populates the following items of the \code{sc3min} slot of the \code{metadata(object)}:
#' \itemize{
#'   \item \code{kmeans_iter_max} - the same as the \code{kmeans_iter_max} argument.
#'   \item \code{kmeans_nstart} - the same as the \code{kmeans_nstart} argument.
#'   \item \code{n_dim} - contains numbers of the number of eigenvectors to be used
#'   in \code{\link[stats]{kmeans}} clustering.
#'   \item \code{rand_seed} - the same as the \code{rand_seed} argument.
#'   \item \code{svm_train_inds} - if SVM is used this item contains indexes of the 
#'   training cells to be used for sc3min clustering and further SVM prediction.
#'   \item \code{svm_study_inds} - if SVM is used this item contains indexes of the
#'    cells to be predicted by SVM.
#'   \item \code{n_cores} - the same as the \code{n_cores} argument.
#' }
#' 
#' @param object an object of \code{SingleCellExperiment} class.
#' @param gene_filter a boolen variable which defines whether to perform gene 
#' filtering before sc3min clustering.
#' @param pct_dropout_min if \code{gene_filter = TRUE}, then genes with percent of dropouts smaller than 
#' \code{pct_dropout_min} are filtered out before clustering.
#' @param pct_dropout_max if \code{gene_filter = TRUE}, then genes with percent of dropouts larger than 
#' \code{pct_dropout_max} are filtered out before clustering.
#' @param d_region_min defines the minimum number of eigenvectors used for 
#' kmeans clustering as a fraction of the total number of cells. Default is \code{0.04}.
#' See \code{sc3min} paper for more details.
#' @param d_region_max defines the maximum number of eigenvectors used for 
#' kmeans clustering as a fraction of the total number of cells. Default is \code{0.07}.
#' See \code{sc3min} paper for more details.
#' @param svm_num_cells number of randomly selected training cells to be used 
#' for SVM prediction. The default is \code{NULL}.
#' @param svm_train_inds a numeric vector defining indeces of training cells 
#' that should be used for SVM training. The default is \code{NULL}.
#' @param svm_max define the maximum number of cells below which SVM is not run.
#' @param n_cores defines the number of cores to be used on the user's machine. If not set, `sc3min` will use all but one cores of your machine.
#' @param kmeans_nstart nstart parameter passed to \code{\link[stats]{kmeans}} function. Default is 
#' \code{1000} for up to \code{2000} cells and \code{50} for more than \code{2000} cells.
#' @param kmeans_iter_max iter.max parameter passed to \code{\link[stats]{kmeans}} 
#' function. Default is \code{1e+09}.
#' @param rand_seed sets the seed of the random number generator. \code{sc3min} is a stochastic
#' method, so setting the \code{rand_seed} to a fixed values can be used for reproducibility
#' purposes.
#' 
#' @name sc3min_prepare
#' @aliases sc3min_prepare sc3min_prepare,SingleCellExperiment-method
#' 
#' @return an object of \code{SingleCellExperiment} class
#' 
#' @importFrom parallel detectCores
#' @importFrom SummarizedExperiment colData colData<- rowData rowData<- assayNames
#' @importFrom S4Vectors metadata metadata<-
#' @importFrom utils capture.output
#' @importFrom methods new
#' @importFrom BiocGenerics counts
#' @importFrom SingleCellExperiment isSpike
sc3min_prepare.SingleCellExperiment <- function(object, gene_filter, pct_dropout_min, pct_dropout_max, 
                                                d_region_min, d_region_max, svm_num_cells, svm_train_inds, svm_max, n_cores, kmeans_nstart, 
                                                kmeans_iter_max, rand_seed) {
  if (is.null(rowData(object)$feature_symbol)) {
    stop("There is no `feature_symbol` column in the `rowData` slot of your dataset! Please write your gene/transcript names to `rowData(object)$feature_symbol`!")
    return(object)
  }
  if (gene_filter == TRUE & !"counts" %in% assayNames(object)) {
    stop("There is no `counts` slot in your input SingleCellExperiment object! sc3min requires the `counts` slot for gene filtering! Please write these values the slot by setting `counts(object) <- count_values`! Alternatively, you can set `gene_filter = FALSE` to switch off gene filtering.")
    return(object)
  }
  if (!"logcounts" %in% assayNames(object)) {
    stop("There is no `logcounts` slot in your input SingleCellExperiment object! sc3min operates on `logcounts` slot, which is supposed to contain both normalised and log-transformed expression values! Please write these values the slot by setting `logcounts(object) <- log_norm_counts`!")
    return(object)
  }
  
  message("Setting sc3min parameters...")
  
  # clean up after the previous sc3min run sc3min slot
  metadata(object)$sc3min <- list()
  colData(object) <- colData(object)[, !grepl("sc3min_", colnames(colData(object))), drop = FALSE]
  rowData(object) <- rowData(object)[, !grepl("sc3min_", colnames(rowData(object))), drop = FALSE]
  
  # gene filter
  f_data <- rowData(object)
  f_data$sc3min_gene_filter <- TRUE
  if (gene_filter) {
    dropouts <- rowSums(counts(object) == 0)/ncol(object)*100
    if(!is.null(isSpike(object))) {
      f_data$sc3min_gene_filter <- dropouts < pct_dropout_max & dropouts > pct_dropout_min & !isSpike(object)
    } else {
      f_data$sc3min_gene_filter <- dropouts < pct_dropout_max & dropouts > pct_dropout_min
    }
    if (all(!f_data$sc3min_gene_filter)) {
      stop("All genes were removed after the gene filter! Please check the `counts` slot of the `SingleCellExperiment` object. It has to contain zeros, where no gene expression was detected. Alternatively, you can set `gene_filter = FALSE` to switch off gene filtering.")
      return(object)
    }
  }
  rowData(object) <- as(f_data, "DataFrame")
  
  metadata(object)$sc3min$kmeans_iter_max <- kmeans_iter_max
  if (is.null(kmeans_nstart)) {
    if (ncol(object) > 2000) {
      metadata(object)$sc3min$kmeans_nstart <- 50
      message("Your dataset contains more than 2000 cells. Adjusting the nstart parameter of kmeans to 50 for faster performance...")
    } else {
      metadata(object)$sc3min$kmeans_nstart <- 1000
    }
  } else {
    metadata(object)$sc3min$kmeans_nstart <- kmeans_nstart
  }
  
  # define number of cells and region of dimensions
  n_dim <- floor(d_region_min * ncol(object)):ceiling(d_region_max * ncol(object))
  # for large datasets restrict the region of dimensions to 15
  if (length(n_dim) > 15) {
    n_dim <- sample(n_dim, 15)
  }
  
  # prepare for SVM
  if (!is.null(svm_num_cells) | !is.null(svm_train_inds) | ncol(object) > svm_max) {
    # handle all possible errors
    if (!is.null(svm_num_cells)) {
      if (!is.null(svm_train_inds)) {
        return(message("You have set both svm_num_cells and svm_train_inds parameters for SVM training. Please set only one of them and rerun sc3min_prepare()."))
      }
      if (svm_num_cells >= ncol(object) - 1) 
        return(message("Number of cells used for SVM training is larger (or equal) than the total number of cells in your dataset. Please make svm_num_cells parameter smaller and rerun sc3min_prepare()."))
      if (svm_num_cells < 10) {
        return(message("Number of cells used for SVM training is less than 10. Please make sure the number of clusters k is smaller than 10 or increase the number of training cells."))
      }
    }
    if (!is.null(svm_train_inds)) {
      if (length(svm_train_inds) < 10) {
        return(message("Number of cells used for SVM training is less than 10. Please make sure the number of clusters k is smaller than 10 or increase the number of training cells."))
      }
      if (max(svm_train_inds) > ncol(object) - 1) {
        return(message("Number of cells used for SVM training is larger than the total number of cells in your dataset. Please adjust svm_train_inds parameter and rerun sc3min_prepare()."))
      }
    }
    # run SVM
    tmp <- prepare_for_svm(ncol(object), svm_num_cells, svm_train_inds, svm_max)
    
    metadata(object)$sc3min$svm_train_inds <- tmp$svm_train_inds
    metadata(object)$sc3min$svm_study_inds <- tmp$svm_study_inds
    
    # update kmeans_nstart after defining SVM training indeces
    if (is.null(kmeans_nstart)) {
      if (length(tmp$svm_train_inds) <= 2000) {
        metadata(object)$sc3min$kmeans_nstart <- 1000
      }
    } else {
      metadata(object)$sc3min$kmeans_nstart <- kmeans_nstart
    }
    
    # update the region of dimensions
    n_dim <- floor(d_region_min * length(tmp$svm_train_inds)):ceiling(d_region_max * length(tmp$svm_train_inds))
    # for large datasets restrict the region of dimensions to 15
    if (length(n_dim) > 15) {
      n_dim <- sample(n_dim, 15)
    }
  }
  
  metadata(object)$sc3min$n_dim <- n_dim
  
  metadata(object)$sc3min$rand_seed <- rand_seed
  
  # register computing cluster (N-1 CPUs) on a local machine
  if (is.null(n_cores)) {
    n_cores <- parallel::detectCores()
    if (is.null(n_cores)) {
      return("Cannot define a number of available CPU cores that can be used by sc3min. Try to set the n_cores parameter in the sc3min() function call.")
    }
    # leave one core for the user
    if (n_cores > 1) {
      n_cores <- n_cores - 1
    }
  }
  
  metadata(object)$sc3min$n_cores <- n_cores
  
  return(object)
}

#' @rdname sc3min_prepare
#' @aliases sc3min_prepare
setMethod("sc3min_prepare", signature(object = "SingleCellExperiment"), sc3min_prepare.SingleCellExperiment)

#' Estimate the optimal number of cluster \code{k} for a scRNA-Seq expression matrix
#' 
#' Uses Tracy-Widom theory on random matrices to estimate the optimal number of
#' clusters \code{k}. It creates and populates the \code{k_estimation} item of the
#' \code{sc3min} slot of the \code{metadata(object)}.
#' 
#' @name sc3min_estimate_k
#' @aliases sc3min_estimate_k sc3min_estimate_k,SingleCellExperiment-method
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' @return an estimated value of k
sc3min_estimate_k.SingleCellExperiment <- function(object) {
  message("Estimating k...")
  dataset <- get_processed_dataset(object)
  res <- estkTW(dataset = dataset)
  metadata(object)$sc3min$k_estimation <- res
  return(object)
}

#' @rdname sc3min_estimate_k
#' @aliases sc3min_estimate_k
setMethod("sc3min_estimate_k", signature(object = "SingleCellExperiment"), sc3min_estimate_k.SingleCellExperiment)

#' Calculate distances between the cells.
#' 
#' This function calculates distances between the cells. It
#' creates and populates the following items of the \code{sc3min} slot of the \code{metadata(object)}:
#' \itemize{
#'   \item \code{distances} - contains a list of distance matrices corresponding to
#'   Euclidean, Pearson and Spearman distances.
#' }
#' 
#' @name sc3min_calc_dists
#' @aliases sc3min_calc_dists, sc3min_calc_dists,SingleCellExperiment-method
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' 
#' @return an object of \code{SingleCellExperiment} class
#' 
#' @useDynLib sc3min
#' @importFrom doRNG %dorng%
#' @importFrom foreach foreach %dopar%
#' @importFrom parallel makeCluster stopCluster
#' @importFrom doParallel registerDoParallel
sc3min_calc_dists.SingleCellExperiment <- function(object) {
  dataset <- get_processed_dataset(object)
  
  # check whether in the SVM regime
  if (!is.null(metadata(object)$sc3min$svm_train_inds)) {
    dataset <- dataset[, metadata(object)$sc3min$svm_train_inds]
  }
  
  # NULLing the variables to avoid notes in R CMD CHECK
  i <- NULL
  
  distances <- c("euclidean", "pearson", "spearman")
  
  message("Calculating distances between the cells...")
  
  if (metadata(object)$sc3min$n_cores > length(distances)) {
    n_cores <- length(distances)
  } else {
    n_cores <- metadata(object)$sc3min$n_cores
  }
  
  cl <- parallel::makeCluster(n_cores, outfile = "")
  doParallel::registerDoParallel(cl, cores = n_cores)
  
  # calculate distances in parallel
  dists <- foreach::foreach(i = distances) %dorng% {
    try({
      calculate_distance(dataset, i)
    })
  }
  
  # stop local cluster
  parallel::stopCluster(cl)
  
  names(dists) <- distances
  
  metadata(object)$sc3min$distances <- dists
  return(object)
}

#' @rdname sc3min_calc_dists
#' @aliases sc3min_calc_dists
setMethod("sc3min_calc_dists", signature(object = "SingleCellExperiment"), sc3min_calc_dists.SingleCellExperiment)

#' Calculate transformations of the distance matrices.
#' 
#' This function transforms all \code{distances} items of the \code{sc3min} slot of 
#' the \code{metadata(object)} using either principal component analysis (PCA) 
#' or by calculating the eigenvectors of the associated graph Laplacian.
#' The columns of the resulting matrices are then sorted in descending order 
#' by their corresponding eigenvalues. The first \code{d} columns 
#' (where \code{d = max(metadata(object)$sc3min$n_dim)}) of each transformation are then 
#' written to the \code{transformations} item of the \code{sc3min} slot.
#' Additionally, this function also removes the previously calculated \code{distances} from
#' the \code{sc3min} slot, as they are not needed for further analysis.
#' 
#' @name sc3min_calc_transfs
#' @aliases sc3min_calc_transfs, sc3min_calc_transfs,SingleCellExperiment-method
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' 
#' @return an object of \code{SingleCellExperiment} class
#' 
#' @importFrom doRNG %dorng%
#' @importFrom foreach foreach
#' @importFrom parallel makeCluster stopCluster
#' @importFrom doParallel registerDoParallel
sc3min_calc_transfs.SingleCellExperiment <- function(object) {
  dists <- metadata(object)$sc3min$distances
  if (is.null(dists)) {
    stop(paste0("Please run sc3min_calc_dists() first!"))
    return(object)
  }
  
  # NULLing the variables to avoid notes in R CMD CHECK
  i <- NULL
  
  distances <- names(dists)
  transformations <- c("laplacian")
  
  n_dim <- metadata(object)$sc3min$n_dim
  
  hash.table <- expand.grid(dists = distances, transfs = transformations, stringsAsFactors = FALSE)
  
  message("Performing transformations and calculating eigenvectors...")
  
  if (metadata(object)$sc3min$n_cores > nrow(hash.table)) {
    n_cores <- nrow(hash.table)
  } else {
    n_cores <- metadata(object)$sc3min$n_cores
  }
  
  cl <- parallel::makeCluster(n_cores, outfile = "")
  doParallel::registerDoParallel(cl, cores = n_cores)
  
  # calculate the 6 distinct transformations in parallel
  #calculate 3 distances in the minimized case.
  transfs <- foreach::foreach(i = 1:nrow(hash.table)) %dorng% {
    try({
      tmp <- transformation(get(hash.table[i, 1], dists), hash.table[i, 2])
      tmp[, 1:max(n_dim)]
    })
  }
  
  # stop local cluster
  parallel::stopCluster(cl)
  
  names(transfs) <- paste(hash.table[, 1], hash.table[, 2], sep = "_")
  
  metadata(object)$sc3min$transformations <- transfs
  # remove distances after calculating transformations
  # metadata(object)$sc3min$distances <- NULL
  return(object)
}

#' @rdname sc3min_calc_transfs
#' @aliases sc3min_calc_transfs
setMethod("sc3min_calc_transfs", signature(object = "SingleCellExperiment"), sc3min_calc_transfs.SingleCellExperiment)

#' \code{kmeans} clustering of cells.
#' 
#' This function performs \code{\link[stats]{kmeans}} clustering of the matrices 
#' contained in the \code{transformations} item of the \code{sc3min} slot of the \code{metadata(object)}. It then
#' creates and populates the following items of the \code{sc3min} slot:
#' \itemize{
#'   \item \code{kmeans} - contains a list of kmeans clusterings.
#' }
#' 
#' @name sc3min_kmeans
#' @aliases sc3min_kmeans, sc3min_kmeans,SingleCellExperiment-method
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' @param ks a continuous range of integers - the number of clusters \code{k} to be used for sc3min clustering.
#' Can also be a single integer.
#' 
#' @return an object of \code{SingleCellExperiment} class
#' 
#' @importFrom doRNG %dorng%
#' @importFrom foreach foreach
#' @importFrom parallel makeCluster stopCluster
#' @importFrom doParallel registerDoParallel
#' @importFrom utils setTxtProgressBar txtProgressBar
#' @importFrom stats kmeans
sc3min_kmeans.SingleCellExperiment <- function(object, ks) {
  if (is.null(ks)) {
    stop(paste0("Please provide a range of the number of clusters `ks` to be used by sc3min!"))
    return(object)
  }
  
  transfs <- metadata(object)$sc3min$transformations
  if (is.null(transfs)) {
    stop(paste0("Please run sc3min_calc_transfs() first!"))
    return(object)
  }
  
  # NULLing the variables to avoid notes in R CMD CHECK
  i <- NULL
  
  n_dim <- metadata(object)$sc3min$n_dim
  
  hash.table <- expand.grid(transf = names(transfs), ks = ks, n_dim = n_dim, stringsAsFactors = FALSE)
  
  message("Performing k-means clustering...")
  
  n_cores <- metadata(object)$sc3min$n_cores
  
  kmeans_iter_max <- metadata(object)$sc3min$kmeans_iter_max
  kmeans_nstart <- metadata(object)$sc3min$kmeans_nstart
  
  cl <- parallel::makeCluster(n_cores, outfile = "")
  doParallel::registerDoParallel(cl, cores = n_cores)
  
  pb <- utils::txtProgressBar(min = 1, max = nrow(hash.table), style = 3)
  
  # calculate the 6 distinct transformations in parallel
  #for the minimized version, we need only 3!, because we only have laplacian
  labs <- foreach::foreach(i = 1:nrow(hash.table)) %dorng% {
    try({
      utils::setTxtProgressBar(pb, i)
      transf <- get(hash.table$transf[i], transfs)
      stats::kmeans(transf[, 1:hash.table$n_dim[i]], hash.table$ks[i], iter.max = kmeans_iter_max, 
                    nstart = kmeans_nstart)$cluster
    })
  }
  
  close(pb)
  
  # stop local cluster
  parallel::stopCluster(cl)
  
  names(labs) <- paste(hash.table$transf, hash.table$ks, hash.table$n_dim, sep = "_")
  
  metadata(object)$sc3min$kmeans <- labs
  return(object)
}

#' @rdname sc3min_kmeans
#' @aliases sc3min_kmeans
setMethod("sc3min_kmeans", signature(object = "SingleCellExperiment"), sc3min_kmeans.SingleCellExperiment)

#' Calculate consensus matrix.
#' 
#' This function calculates consensus matrices based on the clustering solutions
#' contained in the \code{kmeans} item of the \code{sc3min} slot of the \code{metadata(object)}. It then
#' creates and populates the \code{consensus} item of the \code{sc3min} slot with 
#' consensus matrices, their hierarchical clusterings in \code{hclust} objects,
#' and Silhouette indeces of the clusters. It also removes the previously 
#' calculated \code{kmeans} clusterings from
#' the \code{sc3min} slot, as they are not needed for further analysis.
#' 
#' Additionally, it also adds new columns to the \code{colData} slot of the
#' input \code{object}. The column names correspond to the consensus cell labels
#' and have the following format: \code{sc3min_k_clusters}, where \code{k} is the 
#' number of clusters.
#' 
#' @name sc3min_calc_consens
#' @aliases sc3min_calc_consens, sc3min_calc_consens,SingleCellExperiment-method
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' 
#' @return an object of \code{SingleCellExperiment} class
#' 
#' @importFrom doRNG %dorng%
#' @importFrom foreach foreach
#' @importFrom parallel makeCluster stopCluster
#' @importFrom doParallel registerDoParallel
#' @import cluster
#' @importFrom stats hclust dist as.dist
#' 
#' @useDynLib sc3min
#' @import Rcpp
sc3min_calc_consens.SingleCellExperiment <- function(object) {
  k.means <- metadata(object)$sc3min$kmeans
  if (is.null(k.means)) {
    stop(paste0("Please run sc3min_kmeans() first!"))
    return(object)
  }
  
  # NULLing the variables to avoid notes in R CMD CHECK
  i <- NULL
  #range of ks on which we have ran the kmeans
  ks <- as.numeric(unique(unlist(lapply(strsplit(names(k.means), "_"), "[[", 3))))
  
  if (metadata(object)$sc3min$n_cores > length(ks)) {
    n_cores <- length(ks)
  } else {
    n_cores <- metadata(object)$sc3min$n_cores
  }
  
  message("Calculating consensus matrix...")
  
  cl <- parallel::makeCluster(n_cores, outfile = "")
  doParallel::registerDoParallel(cl, cores = n_cores)
  
  
  cons <- foreach::foreach(i = ks) %dorng% {
    try({

      matrix.cols<-names(k.means)
      matrix.rows<-matrix(unlist(k.means), ncol = length(matrix.cols))
      matrix.toCluster<-matrix.rows
      colnames(matrix.toCluster)<-matrix.cols
      res <- consensus_matrix(matrix.toCluster, ks)
      dat<-matrix(data=res$cluster, ncol = length(res$cluster)/ks, nrow = ks)
      
      #library(plyr)
      toList = plyr::alply(dat,1)
      allCons = lapply(toList,FUN = FindSimilarities)
      dat = Reduce("+", allCons)
      colnames(dat) = c(1:ncol(dat))
      rownames(dat) = c(1:nrow(dat))
      tmp = ED2(dat)
      
      diss <- stats::as.dist(as.matrix(stats::as.dist(tmp)))
      
      hc <- stats::hclust(diss)
      clusts <- reindex_clusters(hc, i)
      
      silh <- cluster::silhouette(clusts, diss)
      
      list(consensus = dat, hc = hc, silhouette = silh)
    })
  }
  
  # stop local cluster
  parallel::stopCluster(cl)
  
  names(cons) <- ks
  if(is.null(metadata(object)$sc3min$consensus)) {
    metadata(object)$sc3min$consensus <- list()
  }
  for (n in names(cons)) {
    metadata(object)$sc3min$consensus[[n]] <- cons[[n]]
  }
  metadata(object)$sc3min$bla<-cons
  #remove kmeans results after calculating consensus
  metadata(object)$sc3min$kmeans <- NULL
  
  p_data <- colData(object)
  for (k in ks) {
    hc <- metadata(object)$sc3min$consensus[[as.character(k)]]$hc
    clusts <- reindex_clusters(hc, k)
    # in case of hybrid SVM approach
    if (!is.null(metadata(object)$sc3min$svm_train_inds)) {
      tmp <- rep(NA, nrow(p_data))
      tmp[metadata(object)$sc3min$svm_train_inds] <- clusts
      clusts <- tmp
    }
    p_data[, paste0("sc3min_", k, "_clusters")] <- factor(clusts, levels = sort(unique(clusts)))
  }
  colData(object) <- as(p_data, "DataFrame")
  
  return(object)
}

#' @rdname sc3min_calc_consens
#' @aliases sc3min_calc_consens
setMethod("sc3min_calc_consens", signature(object = "SingleCellExperiment"), sc3min_calc_consens.SingleCellExperiment)


#' Calculate DE genes, marker genes and cell outliers.
#' 
#' This function calculates differentially expressed (DE) genes, marker genes 
#' and cell outliers based on the consensus \code{sc3min} clusterings.
#' 
#' DE genes are calculated using \code{\link{get_de_genes}}. Results of the DE 
#' analysis are saved as new columns in the 
#' \code{featureData} slot of the input \code{object}. The column names correspond 
#' to the adjusted \code{p-value}s of the genes and have the following format: 
#' \code{sc3min_k_de_padj}, where \code{k} is the number of clusters.
#' 
#' Marker genes are calculated using \code{\link{get_marker_genes}}. 
#' Results of the marker gene analysis are saved as three new 
#' columns (for each \code{k}) to the 
#' \code{featureData} slot of the input \code{object}. The column names correspond 
#' to the \code{sc3min} cluster labels, to the adjusted \code{p-value}s of the genes 
#' and to the area under the ROC curve
#' and have the following format: \code{sc3min_k_markers_clusts}, 
#' \code{sc3min_k_markers_padj} and \code{sc3min_k_markers_auroc}, where \code{k} is 
#' the number of clusters.
#' 
#' Outlier cells are calculated using \code{\link{get_outl_cells}}. Results of the 
#' cell outlier analysis are saved as new columns in the 
#' \code{phenoData} slot of the input \code{object}. The column names correspond 
#' to the \code{log2(outlier_score)} and have the following format: 
#' \code{sc3min_k_log2_outlier_score}, where \code{k} is the number of clusters.
#' 
#' Additionally, \code{biology} item is added to the \code{sc3min} slot and is set to
#' \code{TRUE} indicating that the biological analysis of the dataset has been
#' performed.
#' 
#' @name sc3min_calc_biology
#' @aliases sc3min_calc_biology, sc3min_calc_biology,SingleCellExperiment-method
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' @param ks a continuous range of integers - the number of clusters \code{k} to be used for sc3min clustering.
#' Can also be a single integer.
#' @param regime defines what biological analysis to perform. "marker" for
#' marker genes, "de" for differentiall expressed genes and "outl" for outlier
#' cells
#' 
#' @return an object of \code{SingleCellExperiment} class
#' 
#' @importFrom doRNG %dorng%
#' @importFrom foreach foreach
#' @importFrom parallel makeCluster stopCluster
#' @importFrom doParallel registerDoParallel
#' @importFrom methods as
sc3min_calc_biology.SingleCellExperiment <- function(object, ks, regime) {
  if (is.null(metadata(object)$sc3min$consensus)) {
    stop(paste0("Please run sc3min_consensus() first!"))
    return(object)
  }
  if (is.null(ks)) {
    stop(paste0("Please provide a range of the number of clusters `ks` to be used by sc3min!"))
    return(object)
  }
  if (!all(ks %in% as.numeric(names(metadata(object)$sc3min$consensus)))) {
    stop(paste0("Range of the number of clusters ks is not consistent with the consensus results! Please redefine the ks!"))
    return(object)
  }
  if (is.null(regime)) {
    regime <- c("marker", "de", "outl")
  }
  if (!all(regime %in% c("marker", "de", "outl"))) {
    stop(paste0("Regime value must be either 'marker', 'de' or 'outl', or any combination of these three!"))
    return(object)
  }
  
  message("Calculating biology...")
  
  hash.table <- expand.grid(ks = ks, regime = regime, stringsAsFactors = FALSE)
  
  dataset <- get_processed_dataset(object)
  p_data <- colData(object)
  clusts <- as.data.frame(p_data[, grep("sc3min_.*_clusters", colnames(p_data))])
  colnames(clusts) <- colnames(p_data)[grep("sc3min_.*_clusters", colnames(p_data))]
  rownames(clusts) <- rownames(p_data)
  # check whether in the SVM regime
  if (!is.null(metadata(object)$sc3min$svm_train_inds)) {
    dataset <- dataset[, metadata(object)$sc3min$svm_train_inds]
    clusts <- clusts[metadata(object)$sc3min$svm_train_inds, ]
  }
  
  # NULLing the variables to avoid notes in R CMD CHECK
  i <- NULL
  
  if (metadata(object)$sc3min$n_cores > nrow(hash.table)) {
    n_cores <- nrow(hash.table)
  } else {
    n_cores <- metadata(object)$sc3min$n_cores
  }
  
  cl <- parallel::makeCluster(n_cores, outfile = "")
  doParallel::registerDoParallel(cl, cores = n_cores)
  
  biol <- foreach::foreach(i = 1:nrow(hash.table)) %dorng% {
    try({
      get_biolgy(dataset, clusts[, paste0("sc3min_", hash.table[i, 1], "_clusters")], hash.table[i, 2])
    })
  }
  
  # stop local cluster
  parallel::stopCluster(cl)
  
  names(biol) <- paste(hash.table$ks, hash.table$regime, sep = "_")
  
  f_data <- as.data.frame(rowData(object))
  p_data <- as.data.frame(colData(object))
  for (b in names(biol)) {
    k <- strsplit(b, "_")[[1]][1]
    regime <- strsplit(b, "_")[[1]][2]
    # save DE genes
    if(regime == "de") {
      f_data[, paste0("sc3min_", k, "_de_padj")] <- NA
      f_data[, paste0("sc3min_", k, "_de_padj")][which(f_data$sc3min_gene_filter)] <- biol[[b]]
    }
    # save marker genes
    if(regime == "marker") {
      f_data[, paste0("sc3min_", k, "_markers_clusts")] <- NA
      f_data[, paste0("sc3min_", k, "_markers_padj")] <- NA
      f_data[, paste0("sc3min_", k, "_markers_auroc")] <- NA
      f_data[, paste0("sc3min_", k, "_markers_clusts")][which(f_data$sc3min_gene_filter)] <- biol[[b]][, 
                                                                                                       2]
      f_data[, paste0("sc3min_", k, "_markers_padj")][which(f_data$sc3min_gene_filter)] <- biol[[b]][, 
                                                                                                     3]
      f_data[, paste0("sc3min_", k, "_markers_auroc")][which(f_data$sc3min_gene_filter)] <- biol[[b]][, 
                                                                                                      1]
    }
    # save cell outliers
    if(regime == "outl") {
      outl <- biol[[b]]
      # in case of hybrid SVM approach
      if (!is.null(metadata(object)$sc3min$svm_train_inds)) {
        tmp <- rep(NA, nrow(p_data))
        tmp[metadata(object)$sc3min$svm_train_inds] <- outl
        outl <- tmp
      }
      p_data[, paste0("sc3min_", k, "_log2_outlier_score")] <- log2(outl + 1)
    }
  }
  rowData(object) <- as(f_data, "DataFrame")
  colData(object) <- as(p_data, "DataFrame")
  
  metadata(object)$sc3min$biology <- TRUE
  
  return(object)
}

#' @rdname sc3min_calc_biology
#' @aliases sc3min_calc_biology
setMethod("sc3min_calc_biology", signature(object = "SingleCellExperiment"), sc3min_calc_biology.SingleCellExperiment)

#' Run the hybrid \code{SVM} approach.
#' 
#' This method parallelize \code{SVM} prediction for each \code{k} (the number
#' of clusters). Namely, for each \code{k}, \code{\link{support_vector_machines}} 
#' function is utilized to predict the labels of study cells. Training cells are
#' selected using \code{svm_train_inds} item of the \code{sc3min} slot of the
#' \code{metadata(object)}.
#' 
#' Results are written to the \code{sc3min_k_clusters} columns to the 
#' \code{colData} slot of the input \code{object}, where \code{k} is the 
#' number of clusters.
#' 
#' @name sc3min_run_svm
#' @aliases sc3min_run_svm, sc3min_run_svm,SingleCellExperiment-method
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' @param ks a continuous range of integers - the number of clusters \code{k} to be used for sc3min clustering.
#' Can also be a single integer.
#' 
#' @return an object of \code{SingleCellExperiment} class
sc3min_run_svm.SingleCellExperiment <- function(object, ks) {
  if (is.null(metadata(object)$sc3min$svm_train_inds)) {
    stop(paste0("Please rerun sc3min_prepare() defining the training cells!"))
    return(object)
  }
  if (is.null(ks)) {
    stop(paste0("Please provide a range of the number of clusters `ks` to be used by sc3min!"))
    return(object)
  }
  
  dataset <- get_processed_dataset(object)
  p_data <- colData(object)
  svm_train_inds <- metadata(object)$sc3min$svm_train_inds
  svm_study_inds <- metadata(object)$sc3min$svm_study_inds
  
  for (k in ks) {
    clusts <- p_data[, paste0("sc3min_", k, "_clusters")]
    clusts <- clusts[svm_train_inds]
    
    train.dataset <- dataset[, svm_train_inds]
    colnames(train.dataset) <- clusts
    
    study.labs <- support_vector_machines(train.dataset, dataset[, svm_study_inds], "linear")
    svm.labs <- c(clusts, study.labs)
    ord <- order(c(svm_train_inds, svm_study_inds))
    
    p_data[, paste0("sc3min_", k, "_clusters")] <- svm.labs[ord]
  }
  colData(object) <- as(p_data, "DataFrame")
  return(object)
}

#' @rdname sc3min_run_svm
#' @aliases sc3min_run_svm
setMethod("sc3min_run_svm", signature(object = "SingleCellExperiment"), sc3min_run_svm.SingleCellExperiment)

#' Write \code{sc3min} results to Excel file
#' 
#' This function writes all \code{sc3min} results to an excel file.
#' 
#' @param object an object of \code{SingleCellExperiment} class
#' @param filename name of the excel file, to which the results will be written
#' 
#' @name sc3min_export_results_xls
#' @aliases sc3min_export_results_xls
#' 
#' @importFrom WriteXLS WriteXLS
sc3min_export_results_xls.SingleCellExperiment <- function(object, filename) {
  if (is.null(metadata(object)$sc3min$consensus)) {
    stop(paste0("Please run sc3min_consensus() first!"))
  }
  
  p_data <- colData(object)
  f_data <- rowData(object)
  
  res <- list()
  
  if(length(grep("sc3min_", colnames(p_data))) != 0) {
    cells <- as.data.frame(p_data[, grep("sc3min_", colnames(p_data))])
    colnames(cells) <- colnames(p_data)[grep("sc3min_", colnames(p_data))]
    rownames(cells) <- rownames(p_data)
    res[["Cells"]] <- cells
  } else {
    warning("There is no cell data provided by sc3min!")
  }
  if(length(grep("sc3min_", colnames(f_data))) != 0) {
    genes <- as.data.frame(f_data[, grep("sc3min_", colnames(f_data))])
    colnames(genes) <- colnames(f_data)[grep("sc3min_", colnames(f_data))]
    rownames(genes) <- rownames(f_data)
    res[["Genes"]] <- genes
  } else {
    warning("There is no gene data provided by sc3min!")
  }
  
  if(length(res) != 0) {
    WriteXLS(res, ExcelFileName = filename, SheetNames = names(res), 
             row.names = TRUE, AdjWidth = TRUE)
  } else {
    warning("There are no sc3min results in your data object, the Excel file will not be produced. Please run sc3min first!")
  }
}

#' @rdname sc3min_export_results_xls
#' @aliases sc3min_export_results_xls
setMethod("sc3min_export_results_xls", signature(object = "SingleCellExperiment"), sc3min_export_results_xls.SingleCellExperiment)