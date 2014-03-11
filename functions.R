library(rjson)
library(stringr)
library(reshape2)
library(plyr)

setwd("~/fun/starbound")

#function to read in JSON
readJSON <- function(file){
  JSON <- readChar(file, file.info(file)$size)
  JSON <- gsub("//.*?\n","", JSON)
  fromJSON(JSON)
}

#function to write out JSON


#function to create a weather object
weather <- function(w, cpm=0.5){
  ifelse(is.null(cpm), clear<-0, clear <- runif(1, min=cpm))
  ws <- rexp(length(w))
  ws <- (1-clear)*ws/sum(ws)
  ws<-floor(100*ws)/100
  clear<-1-sum(ws)
  c(list(clear, "clear"),
  lapply(1:length(ws), function(x) list(w[x], ws[x])))
}

rep.weather <- function(r, ...){
  lapply(1:r, function(x) weather(...))
}

rep.weather(5, w, NULL)

#list biomes
fl<-list.files(pattern=".surfacebiome$", recursive=T)
fl<-fl[!grepl("detached", fl)]
biomes<-lapply(fl, readJSON)

nm<-gsub("[.].*$", "", fl)
nm<-gsub("^.*/", "", nm)
names(biomes)<-nm


#weather groups
cold<-c("hailstones", "icestorm", "snow", "snowstorm")
vacuum<-c("largemeteor", "meteorshower", "spacedust", "glowingrain")
wet<-c("fog", "drizzle", "rain", "storm")
volcanic <- c("ash", "meteorshower", "glowingrain")
arid <- c("sandstorm")
other <- c("acidrain", "crystalrain")
hazard<-c("hailstones", "largemeteor", "meteorshower", "acidrain")

biomes$arctic$surfaceParameters$weather <- rep.weather(10, cold, .5)
biomes$arid$surfaceParameters$weather <- rep.weather(10, arid, .7)
biomes$asteroidfield$surfaceParameters$weather <- rep.weather(10, vacuum, .5)
biomes$barren$surfaceParameters$weather <- rep.weather(10, vacuum, .5)
biomes$desert$surfaceParameters$weather <- rep.weather(10, arid, .5)
biomes$forest$surfaceParameters$weather <- rep.weather(10, wet, .7)
biomes$grasslands$surfaceParameters$weather <- rep.weather(10, wet, .8)
biomes$jungle$surfaceParameters$weather <- rep.weather(10, wet)
biomes$magma$surfaceParameters$weather <- rep.weather(10, volcanic, .8)
biomes$moon$surfaceParameters$weather <- rep.weather(10, vacuum, .5)
biomes$ocean$surfaceParameters$weather <- rep.weather(10, wet, .5)
biomes$savannah$surfaceParameters$weather <- rep.weather(10, intersect(wet, arid), .8)
biomes$snow$surfaceParameters$weather <- rep.weather(10, cold)
biomes$tentacles$surfaceParameters$weather <- rep.weather(10, "acidrain", .7)
biomes$tundra$surfaceParameters$weather <- rep.weather(10, intersect(cold, wet), .8)
biomes$volcanic$surfaceParameters$weather <- rep.weather(10, volcanic, .5)

