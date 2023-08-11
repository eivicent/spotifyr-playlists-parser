if(!require(spotifyr)){install.packages("spotifyr")}
library(spotifyr)
library(dplyr)

access_token <- get_spotify_access_token(client_id = Sys.getenv("SPOTIFY_CLIENT_ID"),
                                         client_secret = Sys.getenv("SPOTIFY_CLIENT_SECRET"))



playlists <- list()
for(ii in 1:10){
playlists[[ii]] <- get_user_playlists("eivicent",
                                authorization = get_spotify_authorization_code(scope = c("playlist-read-private", "playlist-read-collaborative")), 
                                limit = 50, offset = 50*(ii-1))
}

all_playlists <- playlists %>% bind_rows()

pattern <- "\\b\\d{4}-\\d{2}-\\d{2}\\b"

weekly_playlists <- all_playlists %>% filter(str_detect(name, pattern))

for(jj in 1:nrow(weekly_playlists)){
  tracks <- get_playlist_tracks(playlist_id = weekly_playlists$id[jj])
  
  artists <- tracks$track.artists %>% 
    bind_rows(.id = "song_id") %>% 
    slice_head(n = 1, by = "song_id") %>% 
    select(name)
  
  songs <- tracks %>%  select(date = added_at,
                            duration_ms = track.duration_ms, 
                            song = track.name, 
                            popularity = track.popularity, 
                            release_date = track.album.release_date, 
                            id = track.album.id) %>% 
    mutate(date = as.Date(date))
  
  final_df <- artists %>% bind_cols(songs)
  
  day = as.character(unique(final_df$date))
  
  write.csv2(x = final_df, 
             file = paste0("./weekly_discovers/",day,".csv"),
             row.names = F)
}

