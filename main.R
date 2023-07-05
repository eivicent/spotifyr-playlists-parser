library(spotifyr)
library(tidyverse)
library(pins)

# Set up the SpotifyR credentials
Sys.setenv(SPOTIFY_CLIENT_ID = Sys.getenv("SPOTIFY_CLIENT_ID"))
Sys.setenv(SPOTIFY_CLIENT_SECRET = Sys.getenv("SPOTIFY_CLIENT_SECRET"))

access_token <- get_spotify_access_token()

get_user_playlists("eivicent")

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
  mutate(date = lubridate::as_date(date))

final_df <- artists %>% bind_cols(songs)

board <- pins::board_folder(path = "~/GitHub/spotifyr-playlists-parser/weekly_discovers/", versioned = F)

pins::pin_write(board, x = final_df, name = as.character(unique(final_df$date)),
                type = "csv",versioned = F)
