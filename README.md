How to tame XML with nested data frames and purrr
================
jenny
Sun Feb 28 10:24:50 2016

The second installment in a series: I want to make [`purrr`](https://github.com/hadley/purrr) and [`dplyr`](https://github.com/hadley/dplyr) and [`tidyr`](https://github.com/hadley/tidyr) play nicely with each other. How can I use `purrr` for iteration, while still using `dplyr` and `tidyr` to manage the data frame side of of the house? The first installment is here: [How to obtain a bunch of GitHub issues or pull requests with R](https://github.com/jennybc/analyze-github-stuff-with-r). It has a distinct JSON flavor.

This time I'm using those packages, and a *nested data frame* in particular, to tame some annoying XML from Google spreadsheets.

This is a glorified note-to-self. It might be interesting to a few other people. But I presume a lot of experience with R and a full-on embrace of `%>%`, `dplyr`, etc.

### Load packages

At first I tried to NOT use [`googlesheets`](https://github.com/jennybc/googlesheets) here but Sheet registration is so much easier if I use a prepackaged function and there's nothing to learn by doing it by hand. I'm also using @hrbrmstr's [`xmlview`](https://github.com/hrbrmstr/xmlview) package to pretty print some XML, but note that it really shines for interactive work.

``` r
## devtools::install_github("jennybc/googlesheets")
library(googlesheets)
library(httr)
library(xml2)
suppressMessages(library(dplyr))
suppressMessages(library(purrr))
library(tidyr)
## devtools::install_github("hrbrmstr/xmlview")
library(xmlview) ## highly optional for this example!
```

### The list feed

There are three ways to get information out of a Google spreadsheet and today we are dealing with the ["list feed"](#'%20\href%7Bhttps://developers.google.com/google-apps/spreadsheets/data#work_with_list-based_feeds), which is arguably the most annoying of the bunch. Why do we use it? Let's just assume it's a job that needs to be done.

What makes it so annoying? It extracts Sheet data row-wise. Each row comes back as an XML node, embedded in all sorts of other nodes that redundantly store information we don't need. But, hey, at least it is all very thoroughly namespaced!

The node for a row contains nodes for each cell, among lots of other junk we don't need. The problem is there will be no node for an empty cell. So even though the list feed talks big about being for the consumption of *rectangular data*, it doesn't actually implement that very well. The number of cell nodes can vary across the rows. So we need to address that on the R side, as we create a beautiful data frame for the user.

### Testing sheet

Here is a [testing sheet](https://docs.google.com/spreadsheets/d/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8) I've made. The purpose of the specific worksheet `embedded_empty_cells` is to study and test all 3 methods of consumption w/r/t empty cells.

Key features of this pathological Sheet:

-   Empty cells in the all important header row
-   Random embedded empty cells in the data
-   An entirely empty row
-   An entirely empty column
-   A column with no header BUT with some data in it

FYI: the list feed stops reading once it hits an empty row, though that is not true for other consumption methods.

### Get the XML for row content

Register the testing Sheet, get the URL for the list feed of the `embedded_empty_cells` worksheet, retrieve the data, pull out the XML for the cell contents. Futz with namespaces.

``` r
pts_ws_feed <- "https://spreadsheets.google.com/feeds/worksheets/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/public/full"
(ss <- gs_ws_feed(pts_ws_feed))
#>                   Spreadsheet title: test-gs-public-testing-sheet
#>                  Spreadsheet author: rpackagetest
#>   Date of googlesheets registration: 2016-02-28 18:24:51 GMT
#>     Date of last spreadsheet update: 2016-02-28 17:21:22 GMT
#>                          visibility: public
#>                         permissions: rw
#>                             version: new
#> 
#> Contains 7 worksheets:
#> (Title): (Nominal worksheet extent as rows x columns)
#> embedded_empty_cells: 8 x 7
#> special_chars: 1000 x 26
#> diabolical_column_names: 4 x 8
#> shipwrecks: 1000 x 26
#> for_resizing: 1799 x 30
#> for_updating: 1000 x 26
#> empty: 1000 x 26
#> 
#> Key: 1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8
#> Browser URL: https://docs.google.com/spreadsheets/d/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/
col_names <- TRUE
ws <- "embedded_empty_cells"
index <- match(ws, ss$ws$ws_title)
the_url <- ss$ws$listfeed[index]
req <- GET(the_url)
rc <- read_xml(content(req, as = "text", encoding = "UTF-8"))
ns <- xml_ns_rename(xml_ns(rc), d1 = "feed")
```

Behold the XML. We'll be going after those `entry` nodes -- specifically the sub-nodes associated with the `gsx` namespace. *OK not clear if this works in markdown, but leaving here for anyone who actually walks through the example.*

``` r
xml_view(rc)
```

<!--html_preserve-->

<script type="application/json" data-for="htmlwidget-1933">{"x":{"xmlDoc":"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<feed xmlns=\"http://www.w3.org/2005/Atom\" xmlns:openSearch=\"http://a9.com/-/spec/opensearchrss/1.0/\" xmlns:gsx=\"http://schemas.google.com/spreadsheets/2006/extended\"><id>https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full\u003c/id><updated>2016-02-28T17:21:22.417Z\u003c/updated><category scheme=\"http://schemas.google.com/spreadsheets/2006\" term=\"http://schemas.google.com/spreadsheets/2006#list\"/><title type=\"text\">embedded_empty_cells\u003c/title><link rel=\"alternate\" type=\"application/atom+xml\" href=\"https://docs.google.com/spreadsheets/d/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/pubhtml\"/><link rel=\"http://schemas.google.com/g/2005#feed\" type=\"application/atom+xml\" href=\"https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full\"/><link rel=\"http://schemas.google.com/g/2005#post\" type=\"application/atom+xml\" href=\"https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full\"/><link rel=\"self\" type=\"application/atom+xml\" href=\"https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full\"/><author><name>rpackagetest\u003c/name><email>rpackagetest@gmail.com\u003c/email>\u003c/author><openSearch:totalResults>4\u003c/openSearch:totalResults><openSearch:startIndex>1\u003c/openSearch:startIndex><entry><id>https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/cokwr\u003c/id><updated>2016-02-28T17:21:22.417Z\u003c/updated><category scheme=\"http://schemas.google.com/spreadsheets/2006\" term=\"http://schemas.google.com/spreadsheets/2006#list\"/><title type=\"text\">Argentina\u003c/title><content type=\"text\">year: 1952, pop: 17876956, _chk2m: Americas, lifeexp: 62.485, gdppercap: 5911.315053\u003c/content><link rel=\"self\" type=\"application/atom+xml\" href=\"https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/cokwr\"/><gsx:country>Argentina\u003c/gsx:country><gsx:year>1952\u003c/gsx:year><gsx:pop>17876956\u003c/gsx:pop><gsx:_chk2m>Americas\u003c/gsx:_chk2m><gsx:lifeexp>62.485\u003c/gsx:lifeexp><gsx:gdppercap>5911.315053\u003c/gsx:gdppercap>\u003c/entry><entry><id>https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/cpzh4\u003c/id><updated>2016-02-28T17:21:22.417Z\u003c/updated><category scheme=\"http://schemas.google.com/spreadsheets/2006\" term=\"http://schemas.google.com/spreadsheets/2006#list\"/><title type=\"text\">Argentina\u003c/title><content type=\"text\">year: 1957, pop: 19610538, lifeexp: 64.399, gdppercap: 6856.856212\u003c/content><link rel=\"self\" type=\"application/atom+xml\" href=\"https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/cpzh4\"/><gsx:country>Argentina\u003c/gsx:country><gsx:year>1957\u003c/gsx:year><gsx:pop>19610538\u003c/gsx:pop><gsx:lifeexp>64.399\u003c/gsx:lifeexp><gsx:gdppercap>6856.856212\u003c/gsx:gdppercap>\u003c/entry><entry><id>https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/cre1l\u003c/id><updated>2016-02-28T17:21:22.417Z\u003c/updated><category scheme=\"http://schemas.google.com/spreadsheets/2006\" term=\"http://schemas.google.com/spreadsheets/2006#list\"/><title type=\"text\">Row: 4\u003c/title><content type=\"text\">year: 1962, pop: 21283783, _chk2m: Americas, lifeexp: 65.142, gdppercap: 7133.166023\u003c/content><link rel=\"self\" type=\"application/atom+xml\" href=\"https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/cre1l\"/><gsx:country/><gsx:year>1962\u003c/gsx:year><gsx:pop>21283783\u003c/gsx:pop><gsx:_chk2m>Americas\u003c/gsx:_chk2m><gsx:lifeexp>65.142\u003c/gsx:lifeexp><gsx:gdppercap>7133.166023\u003c/gsx:gdppercap>\u003c/entry><entry><id>https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/chk2m\u003c/id><updated>2016-02-28T17:21:22.417Z\u003c/updated><category scheme=\"http://schemas.google.com/spreadsheets/2006\" term=\"http://schemas.google.com/spreadsheets/2006#list\"/><title type=\"text\">Argentina\u003c/title><content type=\"text\">year: 1967, pop: 22934225, _chk2m: Americas, lifeexp: 65.634\u003c/content><link rel=\"self\" type=\"application/atom+xml\" href=\"https://spreadsheets.google.com/feeds/list/1amnxLg9VVDoE6KSIZvutYkEGNgQyJSnLJgHthehruy8/o2c2ejq/public/full/chk2m\"/><gsx:country>Argentina\u003c/gsx:country><gsx:year>1967\u003c/gsx:year><gsx:pop>22934225\u003c/gsx:pop><gsx:_chk2m>Americas\u003c/gsx:_chk2m><gsx:lifeexp>65.634\u003c/gsx:lifeexp><gsx:gdppercap/>\u003c/entry>\u003c/feed>\n","styleSheet":"default","addFilter":false,"applyXPath":null,"scroll":false,"xmlDocName":"rc"},"evals":[],"jsHooks":[]}</script>
<!--/html_preserve-->
Create a list. Each component holds a nodeset for one spreadsheet row. Use `purrr::map()` to do more XPath work to isolate just the nodes that give cell data.

``` r
(rows <- rc %>%
  xml_find_all("//feed:entry", ns) %>%
  map(~ xml_find_all(.x, xpath = "./gsx:*", ns = ns)))
#> [[1]]
#> {xml_nodeset (6)}
#> [1] <gsx:country>Argentina</gsx:country>
#> [2] <gsx:year>1952</gsx:year>
#> [3] <gsx:pop>17876956</gsx:pop>
#> [4] <gsx:_chk2m>Americas</gsx:_chk2m>
#> [5] <gsx:lifeexp>62.485</gsx:lifeexp>
#> [6] <gsx:gdppercap>5911.315053</gsx:gdppercap>
#> 
#> [[2]]
#> {xml_nodeset (5)}
#> [1] <gsx:country>Argentina</gsx:country>
#> [2] <gsx:year>1957</gsx:year>
#> [3] <gsx:pop>19610538</gsx:pop>
#> [4] <gsx:lifeexp>64.399</gsx:lifeexp>
#> [5] <gsx:gdppercap>6856.856212</gsx:gdppercap>
#> 
#> [[3]]
#> {xml_nodeset (6)}
#> [1] <gsx:country/>
#> [2] <gsx:year>1962</gsx:year>
#> [3] <gsx:pop>21283783</gsx:pop>
#> [4] <gsx:_chk2m>Americas</gsx:_chk2m>
#> [5] <gsx:lifeexp>65.142</gsx:lifeexp>
#> [6] <gsx:gdppercap>7133.166023</gsx:gdppercap>
#> 
#> [[4]]
#> {xml_nodeset (6)}
#> [1] <gsx:country>Argentina</gsx:country>
#> [2] <gsx:year>1967</gsx:year>
#> [3] <gsx:pop>22934225</gsx:pop>
#> [4] <gsx:_chk2m>Americas</gsx:_chk2m>
#> [5] <gsx:lifeexp>65.634</gsx:lifeexp>
#> [6] <gsx:gdppercap/>
```

Put this list of nodesets into a list-column of a data frame, along with a variable for row number. *Is this really the best way to add row number? `dplyr::row_number()` was a bit of a disappointment here.*

``` r
(rows_df <- data_frame(row = seq_along(rows),
                       nodeset = rows))
#> Source: local data frame [4 x 2]
#> 
#>     row          nodeset
#>   (int)           (list)
#> 1     1 <S3:xml_nodeset>
#> 2     2 <S3:xml_nodeset>
#> 3     3 <S3:xml_nodeset>
#> 4     4 <S3:xml_nodeset>
```

Here's the problem with the list feed: the number of cells and the implicit column names vary by row, due to the empty cells in the header row.

``` r
lengths(rows_df$nodeset)
#> [1] 6 5 6 6
```

The main manipulation:

-   Use `purrr::map()` inside `dplyr::mutate()` to unpack the XML.
-   extract the (API-mangled) column name from the node name
-   extract the cell text from the node contents (yes, with the list feed it's always text)
-   create a new variable `i` as a within-row cell counter
-   Use `dplyr::select()` to retain only needed variables. This is where we can drop the `nodeset` list-column. It has served its purpose.
-   Use `tidyr::unnest()` to achieve this:
-   one data frame row per row of spreadsheet --&gt; one data frame row per nonempty cell of spreadsheet

``` r
(cells_df <- rows_df %>%
  mutate(col_name_raw = nodeset %>% map(~ xml_name(.)),
         cell_text = nodeset %>% map(~ xml_text(.)),
         i = nodeset %>% map(~ seq_along(.))) %>%
  select(row, i, col_name_raw, cell_text) %>%
  unnest())
#> Source: local data frame [23 x 4]
#> 
#>      row     i col_name_raw   cell_text
#>    (int) (int)        (chr)       (chr)
#> 1      1     1      country   Argentina
#> 2      1     2         year        1952
#> 3      1     3          pop    17876956
#> 4      1     4       _chk2m    Americas
#> 5      1     5      lifeexp      62.485
#> 6      1     6    gdppercap 5911.315053
#> 7      2     1      country   Argentina
#> 8      2     2         year        1957
#> 9      2     3          pop    19610538
#> 10     2     4      lifeexp      64.399
#> ..   ...   ...          ...         ...
```

### The End

We'll stop this note here, because that's the end of the `purrr + dplyr + tidyr + xml2` stuff. In real life, there's still alot of manipulation needed to make the data frame a user expects, but it's pretty standard.

``` r
devtools::session_info()
#> Session info --------------------------------------------------------------
#>  setting  value                       
#>  version  R version 3.2.3 (2015-12-10)
#>  system   x86_64, darwin13.4.0        
#>  ui       X11                         
#>  language (EN)                        
#>  collate  en_CA.UTF-8                 
#>  tz       America/Vancouver           
#>  date     2016-02-28
#> Packages ------------------------------------------------------------------
#>  package      * version    date      
#>  assertthat     0.1        2013-12-06
#>  cellranger     1.0.0      2015-06-20
#>  curl           0.9.5      2016-01-23
#>  DBI            0.3.1      2014-09-24
#>  devtools       1.10.0     2016-01-23
#>  digest         0.6.9      2016-01-08
#>  dplyr        * 0.4.3.9000 2015-11-24
#>  evaluate       0.8        2015-09-18
#>  formatR        1.2.1      2015-09-18
#>  googlesheets * 0.1.0.9001 2016-02-26
#>  htmltools      0.3        2015-12-29
#>  htmlwidgets    0.6        2016-02-20
#>  httr         * 1.1.0.9000 2016-02-12
#>  jsonlite       0.9.19     2015-11-28
#>  knitr          1.12.6     2016-02-06
#>  lazyeval       0.1.10     2015-01-02
#>  magrittr       1.5        2014-11-22
#>  memoise        0.2.1      2014-04-22
#>  purrr        * 0.2.0.9000 2016-01-31
#>  R6             2.1.2      2016-01-26
#>  Rcpp           0.12.3     2016-01-10
#>  rmarkdown      0.9.5      2016-02-06
#>  stringi        1.0-1      2015-10-22
#>  stringr        1.0.0      2015-04-30
#>  tidyr        * 0.4.1      2016-02-05
#>  xml2         * 0.1.2.9000 2016-01-24
#>  xmlview      * 0.4.7      2016-02-20
#>  yaml           2.1.13     2014-06-12
#>  source                               
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.3)                       
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.3)                       
#>  CRAN (R 3.2.3)                       
#>  Github (hadley/dplyr@4f2d7f8)        
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.0)                       
#>  local                                
#>  CRAN (R 3.2.3)                       
#>  Github (ramnathv/htmlwidgets@5f86cea)
#>  Github (hadley/httr@7261a52)         
#>  CRAN (R 3.2.2)                       
#>  Github (yihui/knitr@37f0531)         
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.0)                       
#>  Github (hadley/purrr@9312764)        
#>  CRAN (R 3.2.3)                       
#>  CRAN (R 3.2.3)                       
#>  Github (rstudio/rmarkdown@5e0ff09)   
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.0)                       
#>  CRAN (R 3.2.3)                       
#>  Github (hadley/xml2@4c4a448)         
#>  Github (hrbrmstr/xmlview@4e93801)    
#>  CRAN (R 3.2.0)
```
