library(spotifyr)
library(tidyverse)

get_my_top_artists_or_tracks(type = 'artists', 
                             time_range = 'long_term', 
                             limit = 5) %>% 
  select(.data$name, .data$genres) %>% 
  rowwise %>% 
  mutate(genres = paste(.data$genres, collapse = ', ')) %>% 
  ungroup()
