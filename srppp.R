library(srppp)
library(DiagrammeR)

current_register <- srppp_dm()
dm_draw(current_register)

current_register$CodeS

# comments (in German)
current_register$CodeS$CodeS_de |> unique()
current_register$CodeR$CodeR_de |> unique()
current_register$application_comments$application_comment_de |> unique()
current_register$obligations$code |> unique()
current_register$obligations$obligation_de |> unique()



current_register$products
current_register$ingredients
current_register$formulation_codes
current_register$substances
