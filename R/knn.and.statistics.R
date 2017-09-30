############################### KNN AND STATISTICS ###############################


# compute knn using the fnn algorithm
# Args:
#   cell.df: the cell data frame used as input
#   input.markers: markers to be used as input for knn
#   k: the number of nearest neighbors to identify
# Returns:
#   nn: list of 2
#     nn.index: index of knn (columns) for each cell (rows)
#     nn.dist: euclidean distance of each k-nearest neighbor
fnn <- function(cell.df, input.markers, k = 100) {
    print("finding k-nearest neighbors")
    input <- cell.df[,input.markers]
    nn <- get.knn(input, k, algorithm = "kd_tree")[[1]]
    print("k-nearest neighbors complete")
    return(nn)
}


# Performs a series of statistical tests on the batch of cells of interest
# Args:
#   basal: tibble of cells corresponding to the unstimulated condition
#   stim: a tibble of cells corresponding to the stimulated condition
#   tests: a vector of strings that the user would like to output (min = statistical test + fold)
#   fold: a string that specifies the use of "median" or "mean" when calculating fold change
#   stat.test: a string that specifies Mann-Whitney U test (mwu) or T test (t) for q value calculation
#   stim.name: a string corresponding to the name of the stim being tested compared to basal
# Returns:
#   result: a named vector corresponding to the results of the "fold change" and mann-whitney u test
run.statistics <- function(basal, stim, fold, stat.test, stim.name) {
    # Edge case of a knn consisting of only one of the two conditions
    # More common in messier datasets
    if(nrow(basal) == 0 | nrow(stim) == 0) {
        return(rep(NA, times = 2*ncol(basal) + 1))
    }

    # Fold change between unstim and stim (output is named vector)
    if(fold == "median") {
        fold <- apply(stim, 2, median) - apply(basal, 2, median)
    } else if (fold == "mean") {
        fold <- apply(stim, 2, mean) - apply(basal, 2, mean)
    } else {
        stop("please select median or mean to be used as input for raw change calculation")
    }

    # Mann-Whitney U test or T test
    if(stat.test == "mwu") {
        qvalue <- sapply(1:ncol(basal), function(j) {
            p <- wilcox.test(basal[[j]], stim[[j]])$p.value
            return(p)
        })
    } else if (stat.test == 't') {
        qvalue <- sapply(1:ncol(basal), function(j) {
            p <- t.test(basal[[j]], stim[[j]])$p.value
            return(p)
        })
    } else {
        stop("please select either Mann-Whitney U test (mwu) or T test (t) for input")
        return()
    }

    # Naming the vectors
    names(qvalue) <- names(fold) # qvalue is not yet a named vector, so its named here
    names(qvalue) <- paste(names(qvalue), stim.name, "qvalue", sep = ".") # specifying
    names(fold) <- paste(names(fold), stim.name, "change", sep = ".") # specifying

    # Get the unstim and stim thresholds done
    fraction.cond2 <- nrow(stim)/sum(nrow(basal), nrow(stim))
    names(fraction.cond2) <- paste(stim.name, "fraction.cond.2", sep = ".")
    result <- c(qvalue, fold, fraction.cond2)
    return(result)
}


# Runs a t test on the medians or means of multiple donors for the same condition
# Args:
#   basal: tibble that contains unstim for a knn including donor identity
#   stim: tibble that contains stim for a knn including donor identity
#   stim.name: string of the name of the current stim being tested
#   donors: vector of strings corresponding to the designated names of the donors
# Returns:
#   result: a named vector of p values (soon to be q values) from the t test done on each marker
multiple.donor.statistics <- function(basal, stim, stim.name, donors) {
    # get the means of all the donors

    basal.stats <- tibble()
    stim.stats <- tibble()
    for(i in donors) {
        basal.curr <- basal[basal$donor == i,] %>% .[!(colnames(.) %in% "donor")]
        stim.curr <- stim[stim$donor == i,] %>% .[!(colnames(.) %in% "donor")]

        basal.mean <- apply(basal.curr, 2, mean)
        stim.mean <- apply(stim.curr, 2, mean)

        basal.stats <- rbind(basal.stats, basal.mean)
        stim.stats <- rbind(stim.stats, stim.mean)
    }
    colnames(basal.stats) <- colnames(basal)[-ncol(basal)] # assumes "donor" always placed at end!
    colnames(stim.stats) <- colnames(stim)[-ncol(basal)]

    # T testing (only if there's no NA in the dataset)
    if(nrow(na.omit(basal.stats)) == length(donors) & nrow(na.omit(stim.stats)) == length(donors)) {
        result <- sapply(1:ncol(basal.stats), function(i) {
            t.test(basal.stats[[i]], stim.stats[[i]])$p.value
        })
    } else {
        result <- rep(NA, times = ncol(basal.stats))
    }


    names(result) <- paste(colnames(basal.stats), stim.name, "replicate.qvalue", sep = ".")
    return(result)
}

# Corrects all p values for multiple hypotheses, sets threshold for which change values
#   should be reported
# Args:
#   cells: tibble of change values, p values, and fraction condition 2
#   threshold: a p value below which the change values will be reported for that cell for that param
q.correction.thresholding <- function(cells, threshold) {
    # Break apart the result
    fold <- cells[,grep("change$", colnames(cells))]
    qvalues <- cells[,grep("qvalue$", colnames(cells))]
    ratio <- cells[,grep("cond2$", colnames(cells))]

    # rest <- cells[,!(colnames(cells) %in% colnames(qvalues))]

    # P value correction
    qvalues <- apply(qvalues, 2, function(x) p.adjust(x, method = "BH")) %>% as.tibble

    # Thresholding the raw change
    if(threshold < 1) {
        names <- colnames(fold)
        fold <- lapply(1:ncol(fold), function(i) {
            curr <- fold[[i]]
            curr <- ifelse(qvalues[[i]] < threshold, curr, 0)
        }) %>% do.call(cbind, .) %>%
            as.tibble()
        colnames(fold) <- names
    }

    #Bring it all together
    result <- bind_cols(qvalues, fold, ratio)
    return(result)
}

# Reports the raw change only if the p value is below a certain number
# Args:
#   fc: vector of fold change values
#   p: vector of p values
#   threshold: number the p value should be below in order for thresholding to take place
# Returns:
#   result: the thresholded raw changes
apply.threshold <- function(fc, p, threshold) {

    # The loop (old school)
    result <- c()
    for(i in 1:length(fc)) {
        fc <- ifelse(p < threshold, fc, 0)
        result <- c(result, fc)
    }
    return(result)
}

# Makes list of all cells within knn, for each knn
# Args:
#   nn.matrix: a matrix of cell index by nearest neighbor index, with values being cell index of the nth nearest neighbor
#   cell.data: tibble of cells by features
#   scone.markers: vector of all markers to be interrogated via statistical testing
#   unstim: an object (used so far: string, number) specifying the "basal" condition
#   threshold: a number indicating the p value the raw change should be thresholded by.
#   fold: a string that specifies the use of "median" or "mean" when calculating fold change
#   stat.test: string denoting Mann Whitney U test ("mwu") or T test ("t)
#   multiple.donor.compare: a boolean that indicates whether t test across multiple donors should be done
# Returns:
#   result: tibble of raw changes and p values for each feature of interest, and fraction of cells with condition 2
scone.values <- function(nn.matrix, cell.data, scone.markers, unstim, threshold = 0.05, fold = "median", stat.test = "mwu", multiple.donor.compare = FALSE) {

    print("running per-knn statistics")

    # Get the donor names if you need it
    if(multiple.donor.compare == TRUE) {
        donors <- unique(cell.data$donor)
    }

    # Get all stim.names
    conditions <- unique(cell.data$condition)
    stims <- conditions[!(conditions %in% unstim)]

    # Variables to be used for progress tracker within the loop
    percent <- nrow(cell.data) %/% 10

    final <- lapply(stims, function(s) {
        # Process each column in the nn matrix
        # This makes a list of vecors corresponding qvalue and fold change
        count <- 0
        result <- lapply(1:nrow(nn.matrix), function(i) {
            # A tracker
            if(i %% percent == 0) {
                count <<- count + 10
                print(paste(count, "percent complete", sep = " "))
            }

            # Index the nn matrix
            curr <- cell.data[nn.matrix[i,],]
            basal <- curr[curr$condition == unstim,] %>% .[,scone.markers]
            stim <- curr[curr$condition == s,] %>% .[,scone.markers] # Change this to specify stim name

            # Fold change cmoparison and Mann-Whitney U test, along with "fraction condition 2"
            output <- run.statistics(basal, stim, fold, stat.test, s)

            # Note that this will overwrite the initial output (for now)
            if(multiple.donor.compare == TRUE) {
                nn.donors <- unique(curr$donor)

                # We want multiple donor testing only if all donors are in each knn
                if(length(unique(nn.donors)) < length(donors)) {
                    donor.output <- rep(NA, times = length(scone)) # Check length
                } else {
                    basal.d <- curr[curr$condition == unstim,] %>% .[,c(scone.markers, "donor")]
                    stim.d <- curr[curr$condition == s,] %>% .[,c(scone.markers, "donor")]
                    donor.output <- multiple.donor.statistics(basal.d, stim.d, s, donors)
                }
                #names(donor.output) <- paste(scone, s, "donor.t.test.qvalue", sep = ".") # Name the donor t test vector
                output <- c(output, donor.output)
            }

            return(output)
        })

        # Melt the list together into a tibble and return it
        result <- do.call(rbind, result) %>%
            as.tibble()

        # print(result[,grep("Stat3", colnames(result))])
        return(result)
    })

    # Returning an error message for the Zunder dataset, but not the Wanderlust dataset
    final <- do.call(cbind, final) %>%
        as.tibble()

    # Do the p value correction, followed by thresholding if you're going to
    frac <- final[, grep("fraction", colnames(final))]
    final <- q.correction.thresholding(final, threshold)
    final <- bind_cols(final, frac)

    print("per-knn statistics complete")

    # Change the only "character" column to a numeric column
    return(final)
}