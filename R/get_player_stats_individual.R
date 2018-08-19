#' Returns a data frame of players, their bio information (age, birth place, etc.), and career statistics for user supplied player URLs and names. 
#' 
#' @param ... Function requires a "player_url", "name." Additional data may be supplied. All of this information comes directly from "get_player_stats_team()" and "get_teams()", if desired.
#' @param .progress Sets a Progress Bar. Defaults to TRUE
#' @param .strip_redundancy Removes variables "name_", "player_url_", and "position_", as they're the same as "name", "player_url", and "position." Defaults to TRUE.
#' @examples 
#' 
#' # The function works in conjunction with get_teams() and get_player_stats_team()
#' teams <- get_teams("ohl", "2017-2018")
#' stats_team <- get_player_stats_team(teams)
#' get_player_stats_individual(stats_team)
#' 
#' # All functions are easily pipeable too
#' get_teams(c("shl", "allsvenskan"), c("2008-2009", "2009-2010", "2010-2011")) %>%
#'   get_player_stats_team(.progress = TRUE) %>%
#'   get_player_stats_individual(.strip_redundancy = FALSE)
#'   
#' # It's also easy to get player stats & bio information for only 1 team   
#' get_teams("ncaa iii", "2017-2018") %>%
#'   filter(team == "Hamilton College") %>%
#'   get_player_stats_team() %>%
#'   get_player_stats_individual()
#'   
#' @export
#' @import dplyr
#' 
get_player_stats_individual <- function(..., .progress = TRUE, .strip_redundancy = TRUE) {
  
  if (.progress) {progress_bar <- progress_estimated(nrow(...), min_time = 0)}
  
  player_stats_individual <- purrr::pmap_dfr(..., function(player_url, name, ...) {
    
    if (.progress) {progress_bar$tick()$print()}
    
    seq(5, 10, by = 0.001) %>%
      sample(1) %>%
      Sys.sleep()
    
    page <- player_url %>% xml2::read_html()
    
    vitals <- page %>%
      rvest::html_nodes('[class="col-xs-8 fac-lbl-dark"]') %>%
      rvest::html_text() %>%
      magrittr::extract(1:9) %>%
      stringr::str_squish() %>%
      purrr::set_names("birthday", "age", "birth_place", "birth_country", "youth_team", "position_", "height", "weight", "shot_handedness") %>%
      t() %>%
      as_tibble() %>%
      mutate(birthday = lubridate::mdy(birthday)) %>%
      mutate(height = stringr::str_split(height, '"', simplify = TRUE, n = 2)[,1]) %>%
      mutate(feet_tall = stringr::str_split(height, "'", simplify = TRUE, n = 2)[,1]) %>%
      mutate(inches_tall = stringr::str_split(height, "'", simplify = TRUE, n = 2)[,2]) %>%
      mutate(height = (as.numeric(feet_tall) * 12) + as.numeric(inches_tall)) %>%
      mutate(weight = stringr::str_split(weight, "lbs", simplify = TRUE, n = 2)[,1]) %>%
      mutate(name_ = name) %>%
      mutate(player_url_ = player_url) %>%
      mutate_all(~stringr::str_trim(., side = "both")) %>%
      mutate_all(~na_if(., "-")) %>%
      mutate_all(~na_if(., "")) %>%
      select(-c(feet_tall, inches_tall, age, youth_team))
    
    player_stats <- page %>%
      rvest::html_node('[class="table table-striped table-condensed table-sortable player-stats highlight-stats"]') %>%
      rvest::html_table() %>%
      purrr::set_names("season_", "team_", "league_", "games_played_", "goals_", "assists_", "points_", "penalty_minutes_", "plus_minus_", "blank_", "playoffs_", "games_played_playoffs_", "goals_playoffs_", "assists_playoffs_", "points_playoffs_", "penalty_minutes_playoffs_", "plus_minus_playoffs_") %>%
      as_tibble() %>%    
      mutate_all(~na_if(., "-")) %>%      
      mutate(captaincy_ = stringr::str_split(team_, "\U201C", simplify = TRUE, n = 2)[,2]) %>%
      mutate(captaincy_ = stringr::str_split(captaincy_, "\U201D", simplify = TRUE, n = 2)[,1]) %>%
      mutate(team_ = stringr::str_split(team_, "\U201C", simplify = TRUE, n = 2)[,1]) %>%
      mutate(season_ = replace(season_, season_ == "", NA)) %>%
      tidyr::fill(season_) %>%
      mutate(season_short_ = as.numeric(stringr::str_split(season_, "-", simplify = TRUE, n = 2)[,1]) + 1) %>%
      mutate(birthday = lubridate::as_date(vitals[["birthday"]])) %>%
      mutate(draft_eligibility_date_ = lubridate::as_date(stringr::str_c(as.character(season_short_), "09-15", sep = "-"))) %>%
      mutate(age_ = get_years_difference(birthday, draft_eligibility_date_)) %>%
      mutate_all(stringr::str_squish) %>%
      mutate_all(as.character) %>%      
      mutate_all(~na_if(., "")) %>%
      select(-c(blank_, playoffs_, draft_eligibility_date_, birthday)) %>%
      select(team_, league_, captaincy_, season_, season_short_, age_, games_played_, goals_, assists_, points_, penalty_minutes_, plus_minus_, games_played_playoffs_, goals_playoffs_, assists_playoffs_, points_playoffs_, penalty_minutes_playoffs_, plus_minus_playoffs_) %>% 
      tidyr::nest()
    
    all_data <- vitals %>% 
      bind_cols(player_stats) %>% 
      rename(player_statistics = data)
    
    return(all_data)
    
  })
  
  mydata <- player_stats_individual %>% 
    bind_cols(...) %>%
    mutate(season_short = as.numeric(stringr::str_split(season, "-", simplify = TRUE, n = 2)[,1]) + 1) %>%
    mutate(draft_eligibility_date = lubridate::as_date(stringr::str_c(as.character(season_short), "09-15", sep = "-"))) %>%
    mutate(age = get_years_difference(lubridate::as_date(birthday), draft_eligibility_date)) %>%
    select(name, team, league, position, shot_handedness, birth_place, birth_country, birthday, height, weight, season, season_short, age, games_played, goals, assists, points, penalty_minutes, plus_minus, games_played_playoffs, goals_playoffs, assists_playoffs, points_playoffs, penalty_minutes_playoffs, plus_minus_playoffs, player_url, team_url, name_, position_, player_url_, player_statistics)
  
  if (.strip_redundancy) {mydata <- mydata %>% select(-c(name_, position_, player_url_))}
  
  return(mydata)
  
}