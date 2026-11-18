# macrodata

MATLAB code that downloads macroeconomic series from public sources and builds quarterly datasets ready for estimating macro models (DSGE, VAR and similar). Every number in the output is downloaded or computed by the code in this repository; nothing is typed in or pasted. The datasets have the form used by Smets and Wouters (2007): one for the United States from FRED, one for the euro area from the ECB Data Portal, built by the same code from one series list.

The code needs base MATLAB (R2019a or later for the optional shadow rate, which comes as an Excel file) and nothing else. It also runs in GNU Octave, except for reading Excel files. Output is plain CSV plus a `.mat` file, so it can be imported into any tool.

## Quick start

```matlab
run('path/to/macrodata/build_dataset.m')   % downloads, builds, writes data/output/
run('path/to/macrodata/tests/run_tests.m') % checks the result against sources and definitions
```

`build_dataset.m` downloads the raw series into `data/raw/<country>/`, builds the dataset and writes (for `country = 'US'`; `ea_` for the euro area)

| File | Content |
|---|---|
| `data/output/us_quarterly.csv` | one row per quarter, one column per variable, missing values empty |
| `data/output/us_quarterly.mat` | the same as a struct `data`, plus `meta` |
| `data/output/us_quarterly_metadata.json` | the options used and the derived numbers (demeaning range, mean of hours, download dates, gaps) |
| `data/output/us_quarterly_dashboard.html` | a page to look at the data; open it in a browser |
| `data/raw/US/download_log.csv` | what was downloaded, from where, when, first and last observation |

Set `opts.country = 'EA'` in the preamble and run again for the euro area.

The `data/` folder is not committed: everyone generates it by running the code. The first run downloads about 3 MB.

All options are in the preamble of `build_dataset.m`:

| Option | Default | Meaning |
|---|---|---|
| `country` | `'US'` | `'US'` or `'EA'`; selects the rows of `series_list.csv` and the build function `build_<country>_quarterly.m` |
| `sample_start`, `sample_end` | `'auto'`, `'last'` | output grid; `'auto'` is 1947Q1 for the US and 1995Q1 for the euro area, `'last'` is the last quarter with real GDP |
| `index_base` | `'auto'` | base quarter of the population and employment indices: 1992Q3 for the US, 1999Q1 for the euro area |
| `population_series` | `'auto'` | series name used for the population: `CNP16OV` for the US; `POP` (annual, interpolated) or `POP1574` (quarterly, from 2009) for the euro area |
| `population` | `'smoothed'` | `'smoothed'` removes the level jumps of the population series with an HP trend; `'raw'` uses the quarterly series as it is |
| `hp_lambda` | `1600` | smoothing parameter of that HP filter |
| `hours_mean_start`, `hours_mean_end` | `'auto'`, `'last'` | range over which hours are demeaned for `labobs`; `'auto'` is 1964Q1 for the US and the first observation for the euro area |
| `rate_aggregation` | `'average'` | `'average'` of the months or `'last'` month of the quarter, for the policy rate, the excess bond premium and the shadow rate |
| `shadow_rate_start`, `shadow_rate_end` | `''`, `''` | replace the policy rate in `robs` by the shadow rate over this range, for example `'2008Q3'` and `'2022Q1'`; empty = never |
| `raw_folder`, `output_folder`, `output_name` | `data/raw`, `data/output`, `'auto'` | where files go; `'auto'` names the output `<country>_quarterly` |
| `download` | `true` | `false` rebuilds from the raw files of an earlier run |
| `make_dashboard` | `true` | write the HTML page |

Every option taken from a country default is listed in the metadata file under `options_resolved_from_auto`.

## What the dataset contains

The grid is quarterly. Monthly and daily source series are aggregated to quarters with the rule stated for each series in `series_list.csv`. Every series is placed on the grid by its date, never by position. A quarter at which a series is not available is missing (empty in the CSV, `NaN` in the `.mat` file); nothing is interpolated or carried forward.

**Model variables** (Smets and Wouters 2007 observables), all in percent. The definitions below are written with the US series names; the euro-area column shows the counterpart.

| Column | Definition |
|---|---|
| `dc` | consumption minus consumption of the previous quarter |
| `dinve` | investment minus investment of the previous quarter |
| `dy` | output minus output of the previous quarter |
| `dw` | real wage minus real wage of the previous quarter |
| `pinfobs` | `100 * (log GDPDEF - log GDPDEF of the previous quarter)` |
| `labobs` | hours minus their mean over `hours_mean_start` to `hours_mean_end`; the range and the mean used are in the metadata file, because with the default end the mean moves when data are added |
| `robs` | policy rate divided by 4 (quarterly average by default): the federal funds rate for the US, the 3-month Euribor for the euro area; over the shadow-rate range, the shadow rate divided by 4 |
| `ebpobs` | excess bond premium, quarterly average by default; all missing for the euro area, which has no such series in the ECB Data Portal |

**Levels and indices**, from which the model variables are built:

| Column | United States | Euro area |
|---|---|---|
| `popidx` | `population / population(1992Q3)`; population is CNP16OV averaged over the quarter and, by default, smoothed as `exp(HP trend of log population)` with lambda 1600 | `population / population(1999Q1)`; population is the annual series POP interpolated to quarters (mid-year values, straight lines between them), smoothed the same way |
| `empidx` | `100 * CE16OV / CE16OV(1992Q3)`, CE16OV averaged over the quarter | `100 * EMP / EMP(1999Q1)` |
| `consumption` | `100 * log((PCEC / GDPDEF) / popidx)` | `100 * log((CONS / GDPDEF) / popidx)` |
| `investment` | `100 * log((FPI / GDPDEF) / popidx)` | `100 * log((INV / GDPDEF) / popidx)` |
| `output` | `100 * log(GDPC1 / popidx)` | `100 * log(GDP / popidx)` |
| `hours` | `100 * log((PRS85006023 * empidx / 100) / popidx)`; the hours index covers the non-farm business sector and is scaled by civilian employment as in Smets and Wouters | `100 * log(HOURS / popidx)`; HOURS is total hours worked in the whole economy, so no scaling by employment |
| `COMP` | not needed (COMPNFB is published) | `1000 * WAGES / HOURS_EMPLOYEES`, wages and salaries per hour worked by employees, euro per hour |
| `realwage` | `100 * log(COMPNFB / GDPDEF)` | `100 * log(COMP / GDPDEF)` |
| `population` | the population series used for `popidx`, thousands of persons | the same |

**Raw series at quarterly frequency**, one column per code in the series list, so that users can build other transformations. When `rate_aggregation` is `'last'`, the columns `FEDFUNDS_last`, `EBP_last` and `SHADOWRATE_last` are added next to the averages.

Why the population is smoothed: the published population series (CNP16OV) has level jumps in the first month of several years, when the Bureau of Labor Statistics introduces new population controls from the census; the jump in January 2000 is 1.4 percent. Each jump goes one for one into per-capita growth rates such as `dy`. The HP trend removes the jumps while keeping the slow movement of the population. Set `population = 'raw'` to use the published series as it is.

## Sources

United States, all from FRED except the last two:

| Name | Series | Source | Native frequency | Quarterly |
|---|---|---|---|---|
| GDPC1 | Real gross domestic product | BEA via FRED | quarterly | as published |
| GDPDEF | GDP implicit price deflator | BEA via FRED | quarterly | as published |
| PCEC | Personal consumption expenditures, nominal | BEA via FRED | quarterly | as published |
| FPI | Fixed private investment, nominal | BEA via FRED | quarterly | as published |
| CE16OV | Civilian employment, 16 and over | BLS via FRED | monthly | average |
| UNRATE | Unemployment rate | BLS via FRED | monthly | average |
| FEDFUNDS | Effective federal funds rate | Federal Reserve Board via FRED | monthly | average (option: last month) |
| CNP16OV | Civilian non-institutional population, 16 and over | BLS via FRED | monthly | average |
| PRS85006023 | Non-farm business sector hours worked, index | BLS via FRED | quarterly | as published |
| COMPNFB | Non-farm business sector hourly compensation, index | BLS via FRED | quarterly | as published |
| EBP | Excess bond premium | Federal Reserve Board, FEDS Notes file | monthly | average (option: last month) |
| SHADOWRATE | Shadow rate, p=3 specification (optional) | De Rezende and Ristiniemi, from Rafael B. De Rezende's website | daily | average (option: last observation) |

Euro area (euro area 20, fixed composition), all from the ECB Data Portal except the shadow rate; the series keys are in `series_list.csv`:

| Name | Series | Native frequency | Quarterly |
|---|---|---|---|
| GDP | Gross domestic product, chain linked volumes, seasonally and calendar adjusted | quarterly | as published |
| GDPDEF | GDP deflator, index 2015 = 100 | quarterly | as published |
| CONS | Final consumption of households and non-profit institutions serving households, current prices | quarterly | as published |
| INV | Gross fixed capital formation, total economy, current prices | quarterly | as published |
| EMP | Total employment, persons | quarterly | as published |
| UNRATE | Unemployment rate, ages 15 to 74, seasonally adjusted (from 2000) | monthly | average |
| EURIBOR3M | 3-month Euribor, monthly average | monthly | average (option: last month) |
| POP | Total population, annual average | annual | interpolated (mid-year values, straight lines between them; no extrapolation beyond the last mid-year) |
| POP1574 | Population aged 15 to 74, Labour Force Survey (from 2009); alternative population series | quarterly | as published |
| HOURS | Total hours worked, total employment | quarterly | as published |
| HOURS_EMPLOYEES | Total hours worked by employees | quarterly | as published |
| WAGES | Wages and salaries (D.11), total economy, current prices | quarterly | as published |
| SHADOWRATE | Shadow rate, p=3 specification, euro-area sheet of the same workbook (optional) | daily | average (option: last observation) |

Compensation of employees (D.1) is not published quarterly for the euro area aggregate in the ECB Data Portal, so wages and salaries (D.11, which excludes employers' social contributions) stand in for it. No euro-area excess bond premium is available from the ECB; add a row named EBP (for example from a published credit-spread dataset) and `ebpobs` is filled automatically.

Sources are the usual ones: FRED for the United States and the ECB Data Portal (the former Statistical Data Warehouse) for the euro area, both by URL without a key. Only series that these do not carry, the excess bond premium and the shadow rate, come from their authors' sites.

FRED series are downloaded without an API key from `https://fred.stlouisfed.org/graph/fredgraph.csv?id=<CODE>`. ECB Data Portal series are downloaded without a key from `https://data-api.ecb.europa.eu/service/data/<FLOW>/<KEY>?format=csvdata`; the ECB's data are free to reuse with attribution under its [terms of use](https://www.ecb.europa.eu/services/using-our-site/disclaimer/html/index.en.html). The excess bond premium comes from the permanent address of the FEDS Note "Updating the Recession Risk and the Excess Bond Premium" (Favara, Gilchrist, Lewis and Zakrajšek, 2016). The shadow rate workbook holds daily estimates for the US, Sweden, the euro area and the UK; the US sheet and the column "Shadow rate, p=3" are used. It is optional: if the file cannot be read (for example in Octave), the build continues without it and `robs` uses the federal funds rate throughout.

Terms of use. The code only downloads at run time; no data are redistributed from this repository. FRED's terms allow such use with attribution and ask that the data not be stored or redistributed; the series used here are produced by US government agencies (BEA, BLS, Federal Reserve Board) and are in the public domain with citation requested. Cite the data as "retrieved from FRED, Federal Reserve Bank of St. Louis" with the series name and code (the `citation` column of `series_list.csv` has the full form for each series). The excess bond premium is a staff research product of the Federal Reserve Board, revised each month over its whole history; cite the FEDS Note. The shadow rate is the authors' estimate; cite De Rezende and Ristiniemi (2023), *A shadow rate without a lower bound constraint*, Journal of Banking and Finance 146, 106686. This project is not endorsed or certified by the Federal Reserve Bank of St. Louis or by any other source.

Gaps in the sources. The household survey of October 2025 was not conducted because of the federal government shutdown, so employment (CE16OV), the unemployment rate (UNRATE) and the population (CNP16OV) have no value for that month, permanently. These three series have `allow_gaps = yes` in the series list. A quarter with a missing month is missing in the quarterly series, so `CE16OV`, `UNRATE`, `CNP16OV`, `empidx`, `hours` and `labobs` are empty in 2025Q4. For the smoothed population only, the missing quarter of log population is bridged by linear interpolation between its neighbours before the HP filter, so that the trend and the per-capita variables exist in 2025Q4; this is printed when it happens and listed in the metadata file under `population_gaps_bridged_for_hp`. With `population = 'raw'` nothing is bridged and the per-capita variables are missing in 2025Q4 as well.

## How the code is organised

```
build_dataset.m                 main script: options, then download, build, write, dashboard
series_list.csv                 one row per series: country, code, source, URL, file format, columns,
                                native frequency, quarterly aggregation, expected start, required, allow_gaps, citation
src/read_series_list.m          reads and checks the list
src/download_series.m           downloads every series, checks it, saves raw files, a .mat file and the log
src/parse_series_file.m         reads a downloaded CSV or Excel file into dates and values
src/to_quarterly.m              daily or monthly to quarterly by date (average, last, sum)
src/hp_filter.m                 Hodrick-Prescott trend
src/build_us_quarterly.m        the US levels; build_ea_quarterly.m the euro-area levels
src/sw_finish.m                 model variables, output struct and metadata, shared by the countries
src/population_index.m          population index, smoothed or raw
src/aggregate_raw.m, rate_group.m, make_grid.m, place_on_grid.m, resolve_options.m
src/write_dataset.m             CSV, .mat and metadata JSON
src/quarter_index.m, quarter_string.m, parse_dates.m, read_csv_cells.m, fetch_url.m, load_raw.m
tests/run_tests.m               the checks listed below
tests/compare_with_smets_wouters_2007.m
dashboard/make_dashboard.m      builds the HTML page from the output files
dashboard/template.html         the page (plain HTML and SVG, no external library)
```

Download and construction are separate: `download_series` saves the raw files with the download date, `build_us_quarterly` only reads them. Running `build_dataset.m` with `download = false` rebuilds from the saved raw files, which is how a build is reproduced later.

## Tests

`tests/run_tests.m` checks the generated files and prints PASS or FAIL for each check (`run_tests('country', 'EA')` for the euro area):

1. Raw series have strictly increasing, regularly spaced dates for their frequency; permitted gaps are listed.
2. The output grid has consecutive quarters without duplicates, and the year and quarter columns match the date label.
3. `popidx` is 1 and `empidx` is 100 in the base quarter.
4. Every constructed column is recomputed from the other columns of the CSV file, so a misaligned or mislabelled column would show.
5. US: the population grows by more than 0.8 percent in 2000Q1 in the raw series and by less than 0.4 percent in the smoothed index. Euro area: no quarterly change of the population index above 1 percent.
6. Second source (needs network). US: the quarterly averages of the monthly FRED series equal FRED's own quarterly aggregation to FRED's rounding, and the last-month values of the federal funds rate equal FRED's end-of-period aggregation exactly. Euro area: the quarterly average of the monthly Euribor is within 0.05 of the ECB's own quarterly series, which averages daily observations. This guards against the mistakes that motivated this repository, such as a monthly column shifted by one row.
7. Reference dataset (needs network, US only): the variables are compared with the original Smets and Wouters (2007) data for 1947Q3 to 2004Q4, downloaded from the copy in Johannes Pfeifer's DSGE_mod repository. `robs` agrees to 0.0025 percentage points from 1954Q3 (rounding of the federal funds rate). Inflation and demeaned hours correlate at 0.99 with the original, the growth rates of output, consumption and investment at 0.98 to 0.99, and the real wage at 0.81; the differences are revisions of the national accounts and of the BLS productivity and cost data since 2005.

Run `run_tests('network', false)` to skip the two checks that download.

## How to add a series

Add a row to `series_list.csv`. For a FRED series, fill in the code, description, units, `FRED` as source, `csv` as format, the native frequency, the quarterly aggregation (`none` for quarterly series, otherwise `average`, `last` or `sum`), the date by which the series must have started, `yes` or `no` for required and for allow_gaps, and the citation. The URL, date column, date format and value column may stay empty for FRED; they follow from the code. For an ECB Data Portal series, put the full series key in the code column (for example `MNA.Q.Y.I9.W2.S1.S1.B.B1GQ._Z._Z._Z.EUR.LR.N` for euro-area real GDP, or `ICP.M.U2.N.000000.4.INX` for the HICP) and `ECB` as source; the URL and the columns again follow from the code. For another source give the full URL of a CSV or Excel file, the sheet name for Excel, and the names of the date and value columns; the date format can be `yyyy-mm-dd`, `yyyy-mm`, `yyyymmdd` or `yyyyQq` (also `yyyy-Qq`). A local file path in the URL column is copied instead of downloaded, for series obtained by other means.

The `name` column is the short name used for the raw file, the output column and in the build function; it must be a valid identifier. The new series is downloaded, checked and written to the output as a quarterly column without any code change. To use it in a model variable, edit the build function. To add a country, add rows with the new country code and a `build_<country>_quarterly.m` function that computes the levels and calls `sw_finish`.

## Dashboard

`dashboard/make_dashboard.m` reads the generated CSV, the metadata file and the raw `.mat` file and writes a self-contained HTML page. It shows sample coverage and the last observation of every series, the options used, each model variable and level with its definition, and every raw series at its native frequency next to its quarterly aggregate, with missing periods marked. The page needs no network connection and no library; the data stay in the generated files.

## Later

- A euro-area credit spread for `ebpobs`.
- Real-time vintages (ALFRED, FRED-MD vintage files). The download date is kept with the data and download and construction are separate, so this can be added without redesign.
- A broader set of indicators (FRED-MD, FRED-QD) through the same series list.

## References

- Smets, F. and Wouters, R. (2007). Shocks and Frictions in US Business Cycles: A Bayesian DSGE Approach. *American Economic Review* 97(3), 586-606.
- Favara, G., Gilchrist, S., Lewis, K. F. and Zakrajšek, E. (2016). Updating the Recession Risk and the Excess Bond Premium. *FEDS Notes*, Board of Governors of the Federal Reserve System, October 6, 2016.
- Gilchrist, S. and Zakrajšek, E. (2012). Credit Spreads and Business Cycle Fluctuations. *American Economic Review* 102(4), 1692-1720.
- De Rezende, R. B. and Ristiniemi, A. (2023). A shadow rate without a lower bound constraint. *Journal of Banking and Finance* 146, 106686.
