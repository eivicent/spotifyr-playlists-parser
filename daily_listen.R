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



start_date <- Sys.Date() - 1
start_time <- as.character((as.integer(floor_date(as.POSIXct(Sys.time(), "GMT"), "day")) - 60*24)*1000)

aux <- get_my_recently_played(authorization = get_spotify_authorization_code(scope = "user-read-recently-played"),
                              after = as.character(start_before*1000),
                              limit = 20)
df <- clean_api_call_output(aux)

aux2 <- get_my_recently_played(authorization = get_spotify_authorization_code(scope = "user-read-recently-played"),
                              after = as.character(as.integer(max(df$played))*1000),
                              limit = 50)

df2 <- clean_api_call_output(aux2)

as_date(max(df2$played))


 






