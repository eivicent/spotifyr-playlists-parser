install.packages("spotifyr")
library(spotifyr)
install.packages("dplyr")
library(dplyr)

access_token <- get_spotify_access_token(client_id = Sys.getenv("SPOTIFY_CLIENT_ID"),
                                         client_secret = Sys.getenv("SPOTIFY_CLIENT_SECRET"))

temp <- get_playlist_tracks(playlist_id = "37i9dQZEVXcGWdRbKjgpyh") 

artists <- temp$track.artists %>% 
  bind_rows(.id = "song_id") %>% 
  slice_head(n = 1, by = "song_id") %>% 
  select(name)

songs <- temp %>%  select(date = added_at,
                          duration_ms = track.duration_ms, 
                          song = track.name, 
                          popularity = track.popularity, 
                          release_date = track.album.release_date, 
                          id = track.album.id) %>% 
  mutate(date = as.Date(date))

final_df <- artists %>% bind_cols(songs)
print(final_df)

day = as.character(unique(final_df$date))

print(day)

write.csv2(x = final_df, 
                    file = paste0("./weekly_discovers/",day,".csv"),
                    row.names = F)
