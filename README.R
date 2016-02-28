#' ---
#'   output: github_document
#'   title: How to tame XML with nested data frames and purrr
#'   always_allow_html: yes
#' ---

#+ setup, echo = FALSE
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.path = "README-"
)

#' The second installment in a series: I want to make
#' [`purrr`](https://github.com/hadley/purrr) and
#' [`dplyr`](https://github.com/hadley/dplyr) and
#' [`tidyr`](https://github.com/hadley/tidyr) play nicely with each other. How
#' can I use `purrr` for iteration, while still using `dplyr` and `tidyr` to
#' manage the data frame side of of the house? The first installment is here:
#' [How to obtain a bunch of GitHub issues or pull requests with
#' R](https://github.com/jennybc/analyze-github-stuff-with-r). It has a distinct
#' JSON flavor.
#'
#' This time I'm using those packages, and a *nested data frame* in particular,
#' to tame some annoying XML from Google spreadsheets.
#'
#' This is a glorified note-to-self. It might be interesting to a few other
#' people. But I presume a lot of experience with R and a full-on embrace of
#' `%>%`, `dplyr`, etc.
#'
#' ### Load packages
#'
#' At first I tried to NOT use
#' [`googlesheets`](https://github.com/jennybc/googlesheets) here but Sheet
#' registration is so much easier if I use a prepackaged function and there's
#' nothing to learn by doing it by hand. I'm also using @hrbrmstr's
#' [`xmlview`](https://github.com/hrbrmstr/xmlview) package to pretty print some
#' XML, but note that it really shines for interactive work.

## devtools::install_github("jennybc/googlesheets")
library(googlesheets)
library(httr)
library(xml2)
suppressMessages(library(dplyr))
suppressMessages(library(purrr))
library(tidyr)
## devtools::install_github("hrbrmstr/xmlview")
library(xmlview) ## highly optional for this example!

#' ### The list feed
#'
#' There are three ways to get information out of a Google spreadsheet and today
#' we are dealing with the ["list feed"](https://developers.google.com/google-apps/spreadsheets/data#work_with_list-based_feeds),
#' which is arguably the most annoying of the bunch. Why do we use it? Let's
#' just assume it's a job that needs to be done.
#'
#' What makes it so annoying? It extracts Sheet data row-wise. Each row comes
#' back as an XML node, embedded in all sorts of other nodes that redundantly
#' store information we don't need. But, hey, at least it is all very thoroughly
#' namespaced!
#'
#' The node for a row contains nodes for each cell, among lots of other junk we
#' don't need. The problem is there will be no node for an empty cell. So even
#' though the list feed talks big about being for the consumption of
#' *rectangular data*, it doesn't actually implement that very well. The number
#' of cell nodes can vary across the rows. So we need to address that on the R
#' side, as we create a beautiful data frame for the user.
#'
#' ### Testing sheet
#'
#' Here is a [testing
#' sheet](https://docs.google.com/spreadsheets/d/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8)
#' I've made. The purpose of the specific worksheet `embedded_empty_cells` is to
#' study and test all 3 methods of consumption w/r/t empty cells.
#'
#' Key features of this pathological Sheet:
#'
#' * Empty cells in the all important header row
#' * Random embedded empty cells in the data
#' * An entirely empty row
#' * An entirely empty column
#' * A column with no header BUT with some data in it
#'
#' FYI: the list feed stops reading once it hits an empty row, though that is
#' not true for other consumption methods.
#'

#' ### Get the XML for row content
#'
#' Register the testing Sheet, get the URL for the list feed of the
#' `embedded_empty_cells` worksheet, retrieve the data, pull out the XML for the
#' cell contents. Futz with namespaces.

pts_ws_feed <- "https://spreadsheets.google.com/feeds/worksheets/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/public/full"
(ss <- gs_ws_feed(pts_ws_feed))
col_names <- TRUE
ws <- "embedded_empty_cells"
index <- match(ws, ss$ws$ws_title)
the_url <- ss$ws$listfeed[index]
req <- GET(the_url)
rc <- read_xml(content(req, as = "text", encoding = "UTF-8"))
ns <- xml_ns_rename(xml_ns(rc), d1 = "feed")

#' Behold the XML. We'll be going after those `entry` nodes -- specifically the
#' sub-nodes associated with the `gsx` namespace. *OK not clear if this works
#' in markdown, but leaving here for anyone who actually walks through the
#' example.*
xml_view(rc)

#' Create a list. Each component holds a nodeset for one spreadsheet row. Use
#' `purrr::map()` to do more XPath work to isolate just the nodes that give cell
#' data.
(rows <- rc %>%
  xml_find_all("//feed:entry", ns) %>%
  map(~ xml_find_all(.x, xpath = "./gsx:*", ns = ns)))

#' Put this list of nodesets into a list-column of a data frame, along with a
#' variable for row number. *Is this really the best way to add row number?
#' `dplyr::row_number()` was a bit of a disappointment here.*
(rows_df <- data_frame(row = seq_along(rows),
                       nodeset = rows))

#' Here's the problem with the list feed: the number of cells and the implicit
#' column names vary by row, due to the empty cells in the header row.
lengths(rows_df$nodeset)

#' The main manipulation:
#'
#' * Use `purrr::map()` inside `dplyr::mutate()` to unpack the XML.
#'   - extract the (API-mangled) column name from the node name
#'   - extract the cell text from the node contents (yes, with the list feed
#'     it's always text)
#'   - create a new variable `i` as a within-row cell counter
#' * Use `dplyr::select()` to retain only needed variables. This is where we
#'   can drop the `nodeset` list-column. It has served its purpose.
#' * Use `tidyr::unnest()` to achieve this:
#'   - one data frame row per row of spreadsheet --> one data frame row per
#'   nonempty cell of spreadsheet
(cells_df <- rows_df %>%
  mutate(col_name_raw = nodeset %>% map(~ xml_name(.)),
         cell_text = nodeset %>% map(~ xml_text(.)),
         i = nodeset %>% map(~ seq_along(.))) %>%
  select(row, i, col_name_raw, cell_text) %>%
  unnest())

#' ### The End
#'
#' We'll stop this note here, because that's the end of the `purrr + dplyr +
#' tidyr + xml2` stuff. In real life, there's still alot of manipulation needed
#' to make the data frame a user expects, but it's pretty standard.

devtools::session_info()
