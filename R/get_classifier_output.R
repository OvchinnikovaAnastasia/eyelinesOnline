get_classifier_output <- function(filename_r2e, filename_classifier, start_epoch, end_epoch, times, dwell_time) {
  classifier <- readChar(filename_classifier, file.info(filename_classifier)$size)
  classifier <- strRep(classifier, '\r', '')
  classifier <- strRep(classifier, 'pipe.trof.classifier2', 'pipe.trof.classifier.output')
  classifier <- strRep(classifier, 'createOutput(RA4,"RES")',sprintf('
createOutput(RA4,"RES")
times <- input(4)
raw_epoch <- cross.windowizeByEvents(input(1), times, %1$i/1000*SI(FS)$samplingRate, %2$i/1000*SI(FS)$samplingRate)
createOutput(raw_epoch, "raw_epochs")
filtered_epochs <- cross.windowizeByEvents(FS, times, %1$i/1000*SI(FS)$samplingRate, %2$i/1000*SI(FS)$samplingRate) 
createOutput(filtered_epochs, "filtered_epochs")', max(dwell_time)+end_epoch-start_epoch, start_epoch))
  
  data <- readStructurized(filename_r2e)
  
  stream <- Filter(function(x) x$name=='EEG', data$streams)[[1]]
  
  rawEEG <- do.call(merge, Filter(function(x){ identical(SI(x), stream) },  data$blocks))
  
  syncTS <- attr(rawEEG, 'TS')[ which(diff(rawEEG[,33])<0)[3]  ]
  
  time_events <- source.events(rep('', length(times)), times*1E3+syncTS)
  
  data$streams[[4]] <- SI(time_events)
  data$streams[[4]]$id = 4
  data$streams[[4]]$name = 'custom_events'
  data$blocks <- c(data$blocks, lapply(time_events, function(x) {
    x <- list(x)
    SI(x) <- data$streams[[4]]
    class(x) <- 'DB.event'
    x
  }))
  
  result <- run.offline(data$streams, data$blocks, classifier)
  
  result.DF <- do.call(rbind,result$RES)
  
  
  cutExcess <- function(epochs, dwell_time){
    mapply(function(eeg, len){
      times <- 1:((len+end_epoch-start_epoch)/1000*SI(epochs)$samplingRate)
      ret <- eeg[times,]
      attr(ret, 'TS') <- attr(eeg, 'TS')[times]
      ret
    }, epochs, dwell_time)
  }
  
  raw_epochs <- cutExcess(result$raw_epochs, dwell_time)
  filtered_epochs <- cutExcess(result$filtered_epochs, dwell_time)
  
  list(classifier_output = result.DF, raw_epochs = raw_epochs, filtered_epochs = filtered_epochs)
}