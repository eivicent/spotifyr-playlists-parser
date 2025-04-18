if(!require(spotifyr)){install.packages("spotifyr")}
library(spotifyr)
library(dplyr)
library(lubridate)

clean_api_call_output <- function(output_from_get_my_recently_played) {
  
  df <- output_from_get_my_recently_played %>% select(played_at, track.name) %>% 
    bind_cols(output_from_get_my_recently_played$track.artists %>% 
                bind_rows(.id = "song_id") %>% 
                slice_head(n = 1, by = "song_id") %>% 
                select(name)) %>% 
    mutate(played = as_datetime(played_at),
           day = date(played))
  return(df)
}

access_token <- get_spotify_access_token(client_id = Sys.getenv("SPOTIFY_CLIENT_ID"),
                                         client_secret = Sys.getenv("SPOTIFY_CLIENT_SECRET"))

file <- "./daily_listen/history.txt"

history <- read.table(file, header = T, sep = ";", quote = "")
names(history) <- c("played_at", "track.name","name", "played", "day")

history <- history %>% 
  mutate(across(played_at:day, ~gsub(x = ., pattern = "\"", replacement = ""))) %>% 
  mutate(played = as.POSIXct(played, "GMT"),
         day = as.Date(day))

start_time <- format(as.integer(max(history$played))*1000,scientific = F)

mytoken <- readRDS("secrets/my_secret")[[1]]

output <- list(); ii <- 1
repeat{
  aux <- get_my_recently_played(authorization = mytoken,
                                after = as.character(start_time), limit = 20)
  
  df <- clean_api_call_output(aux)
  
  output[[ii]] <- df
  start_time <- max(as.character(as.integer(df$played)*1000)); ii <- ii + 1
  Sys.sleep(10)
  if(nrow(df) < 20) break
}

final_df <- bind_rows(output) %>% bind_rows(history)  %>%  arrange(played) %>% 
  mutate(played = as.character(played),
         day = as.character(day),
         name = stringr::str_remove_all(name, ";"),
         name = stringr::str_remove_all(name, "#")) %>% 
  unique()

write.table(x = final_df,  sep = ";", file = file, row.names = F)
