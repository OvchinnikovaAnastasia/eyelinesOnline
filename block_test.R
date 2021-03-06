library(Resonance)
library(R3)
library(Resonate)

file = '/home/mayenok/Yandex.Disk/eyelinesOnline/data/test-4/03.r2e'
blocks <- blockLevelRead(file)

eegBlocks <- Filter(function(b){
  if(!inherits(b, "DataBlock")) return(F)
  if(attr(b, 'stream')!=0) return(F)
  TRUE
}, blocks)

clickBlocks <- Filter(function(b){
  if(!inherits(b, "DataBlock")) return(F)
  if(attr(b, 'stream')!=1) return(F)
  TRUE
}, blocks)



########################

code <- '

require(Resonance)
library(Resonate)
library(eyelinesOnline)

 res <-
structure(list(W = c(-0.0208446002027029, -0.000206079952743263, 
0.035571504594808, 0.00673730722283305, 0.00230352199112655, 
0.0178800744365754, 0.0215243049778507, -0.0365906759629049, 
0.00720923243194915, 0.0390969334706344, 0.0136386538445614, 
-0.0348157870464292, -0.0462857172553094, -0.0130016301381469, 
-0.0236485278059052, -0.0117038643722051, -0.0577499838679864, 
-0.0581184153193551, 0.0173155756798862, -0.0051753032231663, 
0.0119945186889824, -0.00872681073187367, -0.00362025615194892, 
-0.0191710592169192, -0.0452651440379222, -0.027746018207466, 
0.0112579136347722, 0.00880107070941392, 0.0202532727309343, 
0.0242067695197056, -0.0131066837160126, -0.0836066202967502, 
-0.0390308552450691, -0.0418118143269925, 0.0409381750390826, 
0.0452765050689107, 0.0416795379595676, 0.0139402915048073, 0.0155440792657972, 
-0.0197085337833074, -0.0166452248456916, 0.0386029873666579, 
0.00970213278148004, -0.00672774255967826, -0.0187736620543726, 
0.0246981496966144, 0.00331792658992926, -0.0255308719101686, 
-0.0143837388773462, -0.0209336927073705, -0.00900010739156747, 
-0.0558997312373681, -0.0461648287351828, -0.0149666522160733, 
0.0560198103369343, -0.0094750268402913, -0.0166452246586304, 
0.0386029875478002, 0.00970213298451365, -0.00672774234957224, 
-0.0187736618363583, 0.0246981499220093, 0.00331792676327051, 
-0.0255308717687893, -0.0105983752388569, 0.0157673536157857, 
-0.00580045681252247, -0.035489505646804, -0.0071079087536305, 
0.0594770137060551, 0.0733553516638329, 0.111873453225734, 0.013159346032568, 
0.0336545073891376, 0.0412678951965528, -0.0231074746974826, 
-0.034090410808558, -0.0315573603165336, 0.00548668219957916, 
0.0255932751282829, -0.0305234483111311, -0.0676975133707169, 
-0.0497336535364815, -0.0266703565004628, -0.0509765355462355, 
-0.0502604947224449, -0.0763797964007866, -0.0303983903179264, 
0.012410632971409, 0.00464693181298673, 0.0376378866303984, 0.0186807706810034, 
-0.0332800690813722, -0.0246735238599017, -0.0194434016272396, 
0.115612457318256, -0.0191139673996877, 0.0329392702245796, 0.00840052823517388, 
-0.00231479419881003, -0.0112443273164451, 0.0328025579987788, 
0.00505638339091481, -0.0261933212244154), th = -1.70597666660619, 
channels = 1:13, low = FALSE, high = 30, A1 = 14, A2 = 15, 
sRate = 500, bsln_start = 200, bsln_end = 300, left_border = -500, 
epochSize = 750L), .Names = c("W", "th", "channels", "low", 
"high", "A1", "A2", "sRate", "bsln_start", "bsln_end", "left_border", 
"epochSize"))

process = function(){
 FS <- signalPreparation(input(1), low=res$low, high=res$high, notch=50, refs=c(res$A1, res$A2), channels=res$channels)
   
  ev <- input(2)
  RA2 <- cross.windowizeByEvents(FS, ev, (res$epochSize-res$left_border)/1000*SI(FS)$samplingRate, shift=res$left_border/1000*SI(FS)$samplingRate)
  RA3 <- pipe.medianWindow(RA2, (res$bsln_start-res$left_border)/1000* SI(RA2)$samplingRate, (res$bsln_end-res$left_border)/1000* SI(RA2)$samplingRate)
  
  RA4 <- pipe.trof.classifier2(RA3, res$W, res$th, seq(0.3,0.45,0.02)-res$left_border/1000, 0.05)
   createOutput(RA2,"RES")
}
'

########################

A <- matrix(ncol=33,nrow=0)
SI(A) <- SI.channels(channels = 33, samplingRate = 500)
SI(A, 'online') <- T
B <- list()
SI(B) <- SI.event()
SI(B, 'online') <- T

onPrepare(list(A,B), code)


nextEeg <- function(b){
  onDataBlock.double(id = 1, vector = t(b), samples = nrow(b), timestamp = attr(b, 'created'))
}

nextClick <- function(b){
  onDataBlock.message(id = 2, msg = as.character(b), timestamp = attr(b, 'created'))
}

nextBlock <- function(b){
  if(!inherits(b, "DataBlock")) return()
  if(attr(b, 'stream')==0) nextEeg(b) else nextClick(b)
}

lapply(blocks, nextBlock)

Q3 <- popQueue()
