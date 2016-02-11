process_params <- function(l, channels, A1_ch, A2_ch, low, high, bsln_start,
                         bsln_end, left_border)
{  
  
  params <- train_classifier(l$eegT, l$eegNT, l$fixationDuration, l$sRate,
                      l$path, l$epoch_size, A1_ch, A2_ch, bsln_start,
                      bsln_end, left_border, high)
  
  W <- as.numeric(params$W)
  th <- as.numeric(params$th)
  ufeats <- params$feats
  A1 <- as.numeric(params$A1_ch)
  A2 <- as.numeric(params$A2_ch)
  fixDur <- as.numeric(params$fixationDuration)
  sRate <- as.numeric(params$sRate)
  
  t <- fixDur / 1000 * sRate
  
  bsln_start <- (bsln_start / 1000 * l$sRate) - left_border
  bsln_end <- (bsln_end / 1000 * l$sRate) - left_border
  
  
  list(W=W, th=th, ufeats=ufeats, channels=channels, low=low, high=high, A1=A1, A2=A2, fixDur=fixDur, sRate=sRate,
       t=t, bsln_start=bsln_start, bsln_end=bsln_end)
  
  #res
#   cat("\n\n")
#   dump(c("W", "th", "ufeats","channels", "low", "high", "A1", "A2", "fixDur", "sRate",
#          "t", "bsln_start", "bsln_end", "pipe.trof.classifier", "pipe.medianWindow"), file = "")
#   cat("RM <- diag(nrow=33)[channels,]",
#       "FS <- pipeline(",
#       " input(1),",
#       " signalPreparation(, low=low, high=high, notch=50),",
#       " pipe.spatial(, RM),",
#       " pipe.references(, c(A1,A2))", 
#       ")",
#       "#createOutput('niceEEG', FS)",
#       "createOutput('doClick',",
#       "  pipeline(FS,",
#       #      "    pipe.centering(, 500)", 
#       "    pipe.decimate(, 1, 20 , coef_10000_to_500),", 
#       "    cross.windowizeByEvents(, input(2), t/20, shift=-t/20),",
#       "    pipe.medianWindow(, bsln_start/20, bsln_end/20),",
#       "    pipe.trof.classifier(, W, th, ufeats )",
#       "))", sep="\n")
  
}


applyClassifier <- quote({
  RM <- diag(nrow=33)[channels,]
  FS <- pipeline(
    input(1),
    signalPreparation(, low=low, high=high, notch=50),
    pipe.spatial(, RM),
    pipe.references(, c(A1,A2))
  )
  #createOutput('niceEEG', FS)
  doClick <-pipeline(FS,
                     pipe.decimate(, 1, 20 , coef_10000_to_500),
                     cross.windowizeByEvents(, input(2), t/20, shift=-t/20),
                     pipe.medianWindow(, bsln_start/20, bsln_end/20),
                     pipe.trof.classifier(, W, th, ufeats )
  )
  createOutput('doClick', doClick)
})

#' Filter that subtract average for each channel devided by standard deviation
#'
#' @param input Pipe connected to
#' @return Constructed pipe
pipe.centering <- function(input, bufferSize)
{
  bp <- block.processor(input)
  
  buffer <- matrix(0.0, ncol=input$channels, nrow=bufferSize)
  
  input$connect(function(db){
    buffer[1:(bufferSize-nrow(db)),] <<- buffer[(nrow(db)+1):bufferSize,]
    buffer[(bufferSize-nrow(db)+1): bufferSize,] <<- db
    
    bp$emit( DataBlock(db - colMeans(buffer), db) )
  })
  
  bp
}

#' Applying 
#'
#' @param input Pipe connected to
#' @param W array of weights from mat file
#' @param th threshold
#' @param ufeats feature matrix
#' @return Constructed pipe
pipe.trof.classifier <- function(input, W, th, ufeats)
{
  processor(
    input,
    prepare = function(env){
      SI.event()
    },
    online = function(windows){
      lapply(windows, function(db){
        X <- rep(0, dim(ufeats)[[1]])
        for (i in 1:dim(ufeats)[[1]])
        {
          ts <- ufeats[i, 1]
          ch <- ufeats[i, 2]
          X[i] <- db[ts, ch]
        }
        Q = X %*% W
        
        ret <- ( Q < th )
        attr(ret, 'TS') <- attr(db, 'TS')
        ret
      })
    }
  )
}

pipe.medianWindow <- function(input, bsln_start, bsln_end){
  processor(
    input,
    prepare = function(env){
      SI(input)
    },
    online = function(windows){
      lapply(windows, function(db){
        mean_baseline <- colMeans(db[bsln_start:bsln_end, ])
        db[,] <- t(apply(db, 1, function(x) x - mean_baseline))
        db
      })
    }
  )
}