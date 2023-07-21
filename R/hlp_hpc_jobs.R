# ******************************************************************************
# Helper functions for HPC jobs.
# 
# Author: Xiaojie (J) Gao
# Date: 2023-06-16
# ******************************************************************************

HpcJobs <- list(

    #' Check Job status on HPC.
    #' @param details Logical, indicates if detail information is needed.
    #' @return Job info.
    JobStatus = function(details = FALSE) {
        if (details == TRUE) {
            info <- system("bjobs -l", intern = TRUE)
        } else {
            info <- system("bjobs", intern = TRUE)

            if (length(info) == 0) {
                return(info)
            }
            # Convert to a data.frame
            df <- lapply(info, function(x) {
                str <- gsub("\\s+", ",", x)
                row <- strsplit(str, ",")[[1]]
                if (length(row) > 8) {
                    tmp <- row[1:8]
                    tmp[8] <- paste(row[8:length(row)], collapse = " ")
                    row <- tmp
                }
                return(row)
            })
            df <- do.call(rbind, df)
            
            if (length(df) == 0 || nrow(df) <= 1) {
                return(info)
            }

            varnames <- df[1, ]
            df <- data.frame(df[-1, ])
            colnames(df) <- varnames

            info <- df
        }
        return(info)
    },


    #' Kill jobs on HPC.
    #' @param id Job ID. Default is `0`, which means kill all jobs.
    #' @return
    Kill = function(id = 0) {
        command <- paste("bkill", id)
        system(command)
    },


    #' Kill HPC jobs by job name.
    #' @param job_name_regexp A regular expression used to match job name
    #' @export
    KillByName = function(job_name_regexp) {
        info <- HpcJobStatus()
        rows <- info[grep(job_name_regexp, info)]
        for (r in rows) {
            id <- strsplit(r, "\\s+")[[1]][1]
            HpcKill(id)
        }

        # delete all related log files
        log_files <- list.files(file.path("Jobs", "job_log"), full.names = TRUE)
        ff <- log_files[grep(job_name_regexp, log_files)]
        file.remove(ff)
    },


    #' Create a debug node on HPC.
    #' @param n_core Number of cores to request.
    #' @param memory How much memory to request.
    #' @param duration Running duration (in minutes) to request.
    #' @return NULL
    HpcDebugNode = function(n_core = 1, memory = 46, duration = 120) {
        command <- paste(
            "bsub -Is",
            "-n", n_core,
            "-R", paste0("\"rusage[mem=", memory, "GB] select[avx2]\""),
            "-W", duration,
            "tcsh"
        )
        system(command)
    },


    #' Parse job statistics
    #' 
    #' @description
    #' The output stats include:
    #'   - How many jobs finished? how many successful/failed?
    #'   - How much time did a job take? Average, 95% quantiles.
    #'   - How many threads and processes used?
    #'   - How much memory used?
    #' 
    #' @param job_log_file The path of the job log file
    #' @param spec_str A specific line pattern to match
    #'
    #' @return A list.
    ParseLog = function(job_log_file, spec_str = NULL) {
        joblog <- readLines(job_log_file)

        success <- length(grep("Successfully completed.", joblog))
        failed <- length(grep("Exited", joblog))

        cpu_time <- joblog[grep("CPU time", joblog)]
        cpu_time <- sapply(cpu_time, function(str) {
            time_num <- as.numeric(regmatches(str, regexpr("\\d+.\\d+", str)))
            return(time_num)
        }, USE.NAMES = FALSE)
        avgtime <- mean(cpu_time, na.rm = TRUE)
        qr <- quantile(cpu_time, c(0.025, 0.5, 0.975, 1))
        
        spec <- ifelse(!is.null(spec_str), 
            length(grep(spec_str, joblog)), 
            NULL
        )
        
        return(list(
            success = success,
            failed = failed,
            avgtime = avgtime,
            timelwr = qr[1],
            timemed = qr[2],
            timeupr = qr[3],
            timemax = qr[4],
            spec = spec
        ))
    }

)


