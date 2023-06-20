#' @title
#' Generate a quality assessment report of a dataset
#'
#' @description
#' Assesses the content and structure of a dataset and reports possible issues
#' in the dataset and data dictionary to facilitate assessment of input data. 
#' The report can be used to help assess data structure, presence of fields, 
#' coherence across elements, and taxonomy or data dictionary formats. This 
#' report is compatible with Excel and can be exported as an Excel spreadsheet.
#'
#' @details
#' A data dictionary contains metadata about variables and can be associated 
#' with a dataset. It must be a list of data frame-like objects with elements 
#' named 'Variables' (required) and 'Categories' (if any). To be usable in any 
#' function, the 'Variables' element must contain at least the 'name' column, 
#' and the 'Categories' element must contain at least the 'variable' and 'name' 
#' columns. To be considered as a minimum workable data dictionary, in 
#' 'Variables' the 'name' column must also have unique and non-null entries, 
#' and in 'Categories' the combination of 'variable' and 'name' columns must 
#' also be unique'.
#' 
#' A dataset must be a data frame-like object and can be associated with a 
#' data dictionary. If no data dictionary is provided, a minimum workable 
#' data dictionary will be generated as needed by relevant functions. 
#' An identifier `id` column for sorting can be specified by the user. If 
#' specified, the `id` values must be non-missing and will be used in functions 
#' that require it. If no identifier column is specified, indexing is handled 
#' automatically by the function.
#' 
#' A taxonomy is classification scheme that can be defined for variable 
#' attributes. If defined, a taxonomy must be a data frame-like object. It must 
#' be compatible with (and is generally extracted from) an Opal environment. To 
#' work with certain functions, a valid taxonomy must contain at least the 
#' columns 'taxonomy', 'vocabulary', and 'terms'. In addition, the taxonomy
#' may follow Maelstrom research taxonomy, and its content can be evaluated
#' accordingly, such as naming convention restriction, tagging elements,
#' or scales, which are specific to Maelstrom Research. In this particular
#' case, the tibble must also contain 'vocabulary_short', 'taxonomy_scale',
#' 'vocabulary_scale' and 'term_scale' to work with some specific functions.
#'
#' @param dataset A tibble identifying the input dataset observations 
#' associated to its data dictionary.
#' @param data_dict A list of tibble(s) representing meta data of an
#' associated dataset. Automatically generated if not provided.
#' @param taxonomy A tibble identifying the scheme used for variables 
#' classification.
#' @param .dataset_name A character string specifying the name of the dataset
#' (internally used in the function [dossier_evaluate()]).
#' @param as_data_dict_mlstr Whether the output data dictionary has a simple
#' data dictionary structure or not (meaning has a Maelstrom data dictionary
#' structure, compatible with Maelstrom Research ecosystem, including Opal). 
#' TRUE by default.
#'
#' @seealso
#' [dossier_evaluate()]
#'
#' @returns
#' A list of tibbles of report for one data dictionary.
#'
#' @examples
#' {
#' 
#' # use DEMO_files provided by the package
#' library(dplyr)
#' library(fabR) # add_index
#' 
#' #' ###### Example : any data frame (or tibble) can be summarized
#' dataset <- iris['Sepal.Width']
#' dataset_evaluate(dataset)
#' 
#' }
#'
#' @import dplyr tidyr stringr fabR
#' @importFrom crayon bold
#' @importFrom rlang .data
#'
#' @export
dataset_evaluate <- function(
    dataset,
    data_dict = NULL,
    taxonomy = NULL,
    .dataset_name = NULL,
    as_data_dict_mlstr = TRUE){
  
  # future dev
  # add emptiness of the dataset in the Dataset assessment

  fargs <- as.list(match.call(expand.dots = TRUE))

  # check on arguments : dataset
  as_dataset(dataset) # no col_id
  
  if(!is.logical(as_data_dict_mlstr))
    stop(call. = FALSE,
         '`as_data_dict_mlstr` must be TRUE or FALSE (TRUE by default)')
  
  # check on arguments : data_dict
  if(is.null(data_dict)) {
    data_dict <-
      try({data_dict_extract(
        dataset = dataset,
        as_data_dict_mlstr = as_data_dict_mlstr)},silent = TRUE)

    if(class(data_dict)[1] == "try-error") data_dict <-
        data_dict_extract(dataset = dataset,as_data_dict_mlstr = FALSE)}

  as_data_dict_shape(data_dict)
  
  data_dict[['Variables']] <-
    data_dict[['Variables']] %>%
    fabR::add_index(.force = TRUE)

  data_dict <- data_dict[c('Variables','Categories')]
  data_dict <-
    data_dict[!is.na(names(data_dict))] %>%
    lapply(function(x) x %>% mutate(across(everything(),as.character)))

  # add label, valueType and missing if don't exist
  if(as_data_dict_mlstr == TRUE){

    data_dict[['Variables']] <-
      data_dict[['Variables']] %>%
      bind_rows(tibble(valueType = as.character()))

    if(sum(nrow(data_dict[['Categories']])) > 0){
      data_dict[['Categories']] <-
        data_dict[['Categories']] %>%
        bind_rows(tibble(missing = as.character()))}}

  preserve_attributes <- 
    col_id <- attributes(dataset)$`madshapR::col_id`
  
  if(is.null(col_id) | ncol(dataset) == 1){
    dataset <- dataset %>% add_index("___mlstr_index___")
    dataset <- as_dataset(dataset, names(dataset)[1])}
  
  col_id <- attributes(dataset)$`madshapR::col_id`
  # if(!is.null(preserve_attributes)) col_id <- preserve_attributes
  
  zap_dataset <- 
    dataset_zap_data_dict(dataset) %>% 
    select(-all_of(col_id))
  
  dataset_name <-
    ifelse(!is.null(.dataset_name),.dataset_name,
           fabR::make_name_list(
             as.character(fargs[['dataset']]),list_elem = list(NULL)))

  # check on argument : taxonomy
  if(!is.null(taxonomy)) as_taxonomy(taxonomy)

  # creation of the structure of the report
  report <- data_dict_evaluate(data_dict,as_data_dict_mlstr= as_data_dict_mlstr)
  
  message(
    "- DATASET ASSESSMENT: ",
    crayon::bold(dataset_name), if(dataset %>% nrow == 0) " (empty dataset)",
    " --------------------------")

  test_name_standards <-
    test_matching_variable <-
    test_duplicated_columns <-
    test_duplicated_rows <-
    test_empty_row <-
    test_empty_col <-
    test_unique_value <-
    test_existing_variable_category <-
    test_valueType <-
    tibble(name_var = as.character())

  message(
"    Assess the standard adequacy of naming")
  test_name_standards  <- 
    check_name_standards(names(zap_dataset))
  
  message(
"    Assess the presence of variable names both in dataset and data dictionary")
  test_matching_variable <-
    check_dataset_variables(dataset, data_dict) %>%
    filter(.data$`name_var` != '___mlstr_index___') %>% 
    filter(
      str_detect(
        .data$`condition`,"Variable only present") & !is.na(.data$`name_var`)) 
  
  message(
    "    Assess the presence of possible duplicated variable in the dataset")
  if(dataset %>% nrow > 0){
    test_duplicated_columns <-
      fabR::get_duplicated_cols(
        dataset %>% select(-matches('___mlstr_index___'))) %>%
      rename(name_var = "name_col")
  }
  
  message(
    "    Assess the presence of duplicated participants in the dataset")
  if(dataset %>% nrow > 0){
    test_duplicated_rows <-
      fabR::get_duplicated_rows(tbl = dataset, id_col = col_id) %>%
      mutate(
        value = str_remove(
          .data$`condition`,
          "\\[INFO\\] - Duplicated observations : ")) %>%
      fabR::add_index('index') %>%
      separate_rows(.data$`value`,sep = " ; ") %>%
      group_by(.data$`index`) %>%
      fabR::add_index('index2') %>%
      group_by(.data$`index`) %>%
      slice(1:6) %>%
      mutate(
        value = 
          ifelse(.data$`index2` == 6 , "[...]",.data$`value`)) %>%
      summarise(`value` = paste0(.data$`value`, collapse = " ; ")) %>%
      mutate(condition = "[INFO] - possible duplicated row values") %>%
      mutate(
        `name_var` = 
          ifelse(col_id == "___mlstr_index___",NA_character_, !! col_id)) %>%
      select(-"index") 
  }
  
  if(dataset %>% nrow > 0){
    message("    Assess the presence of unique value columns in dataset")
    test_unique_value <-
      fabR::get_unique_value_cols(zap_dataset) %>%
      rename(`name_var` = "name_col") %>%
      distinct()
  }
  
  message(
    "    Assess the presence of empty rows in the data dictionary")
  test_empty_row <-
    fabR::get_all_na_rows(dataset,id_col = col_id) %>%
    mutate(
      condition =
        "[INFO] - Empty participant(s) (Except participant identifier column)")
  
  message(
    "    Assess the presence all NA(s) of columns in the data dictionary")
  test_empty_col <-
    fabR::get_all_na_cols(dataset) %>%
    rename(`name_var` = "name_col")
  
  message(
    "    Assess the presence of categories not in the data dictionary")
  
  test_existing_variable_category <-
    suppressMessages({
      check_dataset_categories(dataset,data_dict) %>%
        distinct() %>% group_by(.data$`condition`,.data$`name_var`) %>%
        summarise(
          `value` = paste0(.data$`value`, collapse = " ; "),.groups = 'keep')
    }) %>%
    filter(!is.na(.data$`name_var`)) %>%
    ungroup()
  
  if(as_data_dict_mlstr == TRUE){
    message(
      "    Assess the `valueType` comparison in dataset and data dictionary")
    test_valueType <-
      check_dataset_valueType(
       dataset = zap_dataset, 
       data_dict = data_dict['Variables'],valueType_guess = TRUE)}
  
  # test_name_standards
  # test_matching_variable
  # test_duplicated_columns
  # test_duplicated_rows
  # test_empty_row
  # test_empty_col
  # test_unique_value
  # test_existing_variable_category
  # test_valueType
  
  report$`Dataset assessment` <-
    test_name_standards %>%
    bind_rows(test_matching_variable) %>%
    bind_rows(test_duplicated_columns) %>%
    bind_rows(test_duplicated_rows) %>%
    bind_rows(test_empty_row) %>%
    bind_rows(test_empty_col) %>%
    bind_rows(test_unique_value) %>%
    bind_rows(test_existing_variable_category) %>%
    bind_rows(test_valueType) %>%
    
    select(
      name = "name_var",
      `Quality assessment comment` = "condition", everything()) %>%
    mutate(across(everything(), ~ as.character(.))) %>%
    distinct() %>% tibble %>%
    left_join(
      report$`Data dictionary summary` %>%
        select("index", "name"),
      by = 'name') %>% 
    select('index in data dict.' = "index", "name", everything()) %>%
    arrange(.data$`index in data dict.`)
  
  message("    Generate report")
  
  if(nrow(report$`Dataset assessment`) == 0){
    message("\n    The dataset contains no error/warning.")
    report$`Dataset assessment` <- NULL
  }
  
  message(bold(
    "
  - WARNING MESSAGES (if any): -------------------------------------------------
    "
  ))
  
  return(report)
}

#' @title
#' Generate a quality assessment report of a dossier (list of datasets)
#'
#' @description
#' Assesses the content and structure of a dossier object (list of 
#' datasets) and reports possible issues in the datasets and data dictionaries 
#' to facilitate assessment of input data. 
#' The report can be used to help assess data structure, presence of fields, 
#' coherence across elements, and taxonomy or data dictionary formats.This 
#' report is compatible with Excel and can be exported as an Excel spreadsheet.
#'
#' @details
#' A dossier must be a named list containing at least one data frame or
#' data frame extension (e.g. a tibble), each of them being datasets.
#' The name of each tibble will be use as the reference name of the dataset.
#' 
#' A taxonomy is classification scheme that can be defined for variable 
#' attributes. If defined, a taxonomy must be a data frame-like object. It must 
#' be compatible with (and is generally extracted from) an Opal environment. To 
#' work with certain functions, a valid taxonomy must contain at least the 
#' columns 'taxonomy', 'vocabulary', and 'terms'. In addition, the taxonomy
#' may follow Maelstrom research taxonomy, and its content can be evaluated
#' accordingly, such as naming convention restriction, tagging elements,
#' or scales, which are specific to Maelstrom Research. In this particular
#' case, the tibble must also contain 'vocabulary_short', 'taxonomy_scale',
#' 'vocabulary_scale' and 'term_scale' to work with some specific functions.
#'
#' @param dossier List of tibble, each of them being datasets.
#' @param taxonomy A tibble identifying the scheme used for variables 
#' classification.
#' @param as_data_dict_mlstr Whether the output data dictionary has a simple
#' data dictionary structure or not (meaning has a Maelstrom data dictionary
#' structure, compatible with Maelstrom Research ecosystem, including Opal). 
#' TRUE by default.
#'
#' @returns
#' A list of tibbles of report for each dataset.
#'
#' @examples
#' {
#' 
#' # use DEMO_files provided by the package
#' library(dplyr)
#' library(stringr)
#'
#' ###### Example : a dataset list is a dossier by definition.
#' dossier_evaluation <- dossier_evaluate(
#'   DEMO_files[str_detect(names(DEMO_files),"dataset_MELBOURNE")])
#'
#' glimpse(dossier_evaluation)
#'
#' }
#'
#' @import dplyr stringr tidyr
#' @importFrom crayon bold
#' @importFrom rlang .data
#' @export
dossier_evaluate <- function(
    dossier, taxonomy = NULL, as_data_dict_mlstr = TRUE){
  
  # amelioration :rajouter taxonomy
  
  # check on arguments
  as_dossier(dossier)
  if(!is.null(taxonomy)) as_taxonomy(taxonomy)
  if(!is.logical(as_data_dict_mlstr))
    stop(call. = FALSE,
         '`as_data_dict_mlstr` must be TRUE or FALSE (TRUE by default)')
  
  report_list <-
    vector(mode = "list", length = length(names(dossier)))
  names(report_list) <- names(dossier)
  
  message(crayon::bold(
    "- DOSSIER ASSESSMENT: ----------------------------------------------------"
  ))
  
  for(i in seq_len(length(dossier))){
    # stop()}
    report_list[[i]] <-
      dataset_evaluate(
        dataset = dossier[[i]],
        taxonomy = taxonomy,
        .dataset_name = names(dossier[i]),
        as_data_dict_mlstr = as_data_dict_mlstr)
  }
  
  return(report_list)
}

#' @title
#' Generate a quality assessment report of a data dictionary
#'
#' @description
#' Assesses the content and structure of a data dictionary and reports potential
#' issues to facilitate the assessment of input data. 
#' The report can be used to help assess data structure, presence of fields, 
#' coherence across elements, and taxonomy or data dictionary formats. This 
#' report is compatible with Excel and can be exported as an Excel spreadsheet.
#'
#' @details
#' A data dictionary contains metadata about variables and can be associated 
#' with a dataset. It must be a list of data frame-like objects with elements 
#' named 'Variables' (required) and 'Categories' (if any). To be usable in any 
#' function, the 'Variables' element must contain at least the 'name' column, 
#' and the 'Categories' element must contain at least the 'variable' and 'name' 
#' columns. To be considered as a minimum workable data dictionary, in 
#' 'Variables' the 'name' column must also have unique and non-null entries, 
#' and in 'Categories' the combination of 'variable' and 'name' columns must 
#' also be unique'.
#' 
#' A taxonomy is classification scheme that can be defined for variable 
#' attributes. If defined, a taxonomy must be a data frame-like object. It must 
#' be compatible with (and is generally extracted from) an Opal environment. To 
#' work with certain functions, a valid taxonomy must contain at least the 
#' columns 'taxonomy', 'vocabulary', and 'terms'. In addition, the taxonomy
#' may follow Maelstrom research taxonomy, and its content can be evaluated
#' accordingly, such as naming convention restriction, tagging elements,
#' or scales, which are specific to Maelstrom Research. In this particular
#' case, the tibble must also contain 'vocabulary_short', 'taxonomy_scale',
#' 'vocabulary_scale' and 'term_scale' to work with some specific functions.
#'
#' @param data_dict A list of tibble(s) representing meta data to be evaluated.
#' @param taxonomy A tibble identifying the scheme used for variables
#' classification as a tibble.
#' @param as_data_dict_mlstr Whether the output data dictionary has a simple
#' data dictionary structure or not (meaning has a Maelstrom data dictionary
#' structure, compatible with Maelstrom Research ecosystem, including Opal). 
#' TRUE by default.
#'
#' @returns
#' A list of tibbles of report for one data dictionary.
#'
#' @examples
#' {
#' 
#' # use DEMO_files provided by the package
#'
#' data_dict <- DEMO_files$`dd_TOKYO_format_maelstrom_tagged - ERROR`
#' data_dict_evaluate(data_dict)
#'
#' }
#'
#' @import dplyr tidyr stringr fabR
#' @importFrom crayon bold
#' @importFrom rlang .data
#'
#' @export
data_dict_evaluate <- function(
    data_dict,
    taxonomy = NULL,
    as_data_dict_mlstr = TRUE){
  
  fargs <- as.list(match.call(expand.dots = TRUE))
  
  data_dict_name <-
    fabR::silently_run(
      fabR::make_name_list(args_list = fargs['data_dict'], list(NULL)))
  
  # check args
  if(!is.logical(as_data_dict_mlstr))
    stop(call. = FALSE,
         '`as_data_dict_mlstr` must be TRUE or FALSE (TRUE by default)')
  
  # check on arguments : data_dict
  as_data_dict_shape(data_dict)
  data_dict[['Variables']] <-
    data_dict[['Variables']] %>%
    fabR::add_index(.force = TRUE)
  
  data_dict <- data_dict[c('Variables','Categories')]
  data_dict <-
    data_dict[!is.na(names(data_dict))] %>%
    lapply(function(x) x %>% mutate(across(everything(),as.character)))
  
  # add label, valueType and missing if don't exist
  if(as_data_dict_mlstr == TRUE){
    
    data_dict[['Variables']] <-
      data_dict[['Variables']] %>%
      bind_rows(tibble(valueType = as.character()))
    
    if(length(names(
      data_dict[['Variables']] %>%
      select(matches(c("^label$","^label:[[:alnum:]]"))))) == 0){
      
      data_dict[['Variables']] <-
        data_dict[['Variables']] %>%
        bind_rows(tibble(label = as.character()))
    }
    
    if(sum(nrow(data_dict[['Categories']])) > 0){
      
      data_dict[['Categories']] <-
        data_dict[['Categories']] %>%
        bind_rows(tibble(missing = as.character()))
      
      if(length(names(
        data_dict[['Categories']] %>%
        select(matches(c("^label$","^label:[[:alnum:]]"))))) == 0){
        
        data_dict[['Categories']] <-
          data_dict[['Categories']] %>%
          bind_rows(tibble(label = as.character()))
      }
    }
  }
  
  # check on arguments : taxonomy
  if(!is.null(taxonomy)) taxonomy <- as_taxonomy(taxonomy)
  
  message(
"- DATA DICTIONARY ASSESSMENT: ",crayon::bold(data_dict_name)," --------------")
  
  # creation of the structure of the report
  report <- list()
  
  report$`Data dictionary summary` <-
    suppressWarnings(data_dict_collapse(data_dict))
  report$`Data dictionary summary` <-
    tibble(report$`Data dictionary summary`[['Variables']] %>%
             select(
               .data$`index`,.data$`name`,
               matches(c("^label$","^label:[[:alnum:]]"))[1],
               matches('^valueType$'),starts_with("Categories::"),
               everything())) %>%
    mutate(index = as.integer(.data$`index`))
  
  test_name_standards <-
    test_unique_variable <-
    test_duplicated_columns <-
    # test_duplicated_rows <-
    test_empty_row <-
    test_empty_col <-
    test_existing_variable_category <-
    test_var_label <-
    test_valueType <-
    test_cat_label <-
    test_missing_category <-
    tibble(name_var = as.character())
  
  message("    Assess the standard adequacy of naming")
  test_name_standards  <-
    check_name_standards(data_dict[['Variables']][['name']]) %>%
    mutate(
      name_col = "name",
      sheet    = "Variables") %>%
    bind_rows(
      if(sum(nrow(data_dict[['Categories']])) > 0 ){
        check_name_standards(data_dict[['Categories']][['variable']]) %>%
          mutate(
            name_col = "name",
            sheet    = "Categories")
      }else{tibble(name_var = as.character())})
  
  message("    Assess the uniqueness of variable names")
  test_unique_variable <-
    check_data_dict_variables(data_dict) %>%
    mutate(
      name_col = "name",
      sheet    = "Variables")
  
  message("    Assess the presence of possible duplicated columns")
  test_duplicated_columns <-
    suppressWarnings(fabR::get_duplicated_cols(data_dict[['Variables']])) %>%
    mutate(sheet    = "Variables") %>%
    bind_rows(
      if(sum(nrow(data_dict[['Categories']])) > 0 ){
        suppressWarnings(
          fabR::get_duplicated_cols(data_dict[['Categories']])) %>%
          mutate(sheet    = "Categories")
      }else{tibble()})
  
  # message("    Assess the presence of duplicated variable in the dataset")
  # test_duplicated_rows <-
  #   fabR::get_duplicated_rows(data_dict[['Variables']] %>%
  #    select(-.data$`name`)) %>%
  #   mutate(
  #     condition = str_remove(.data$`condition`,
  #                 "\\[INFO\\] - Possible duplicated observations: ")) %>%
  #   separate_rows(.data$`condition`,sep = " ; ") %>%
  #   mutate(index = as.integer(.data$`condition`)) %>%
  #   full_join(data_dict[['Variables']] %>% fabR::add_index(.force = TRUE),
  #                                                            by = "index") %>%
  #   filter(!is.na(.data$`condition`)) %>%
  #   select(col_name = .data$`name`) %>%
  #   summarise(col_name = paste0(.data$`col_name`, collapse = " ; ")) %>%
  #   mutate(
  #     condition = "[INFO] - possible duplicated rows (variables)",
  #     sheet    = "Variables")
  
  message("    Assess the presence of empty rows in the data dictionary")
  test_empty_row <-
    data_dict[['Variables']] %>% select(.data$`name`, everything()) %>%
    fabR::get_all_na_rows() %>%
    rename(name_col = .data$`value`) %>%
    mutate(
      condition = "[INFO] - Empty line(s)",
      sheet    = "Variables")
  
  message("    Assess the presence of empty columns in the data dictionary")
  test_empty_col <-
    fabR::get_all_na_cols(
      data_dict[['Variables']] %>% select(-.data$`name`)) %>%
    mutate(sheet    = "Variables") %>%
    bind_rows(
      if(sum(nrow(data_dict[['Categories']])) > 0 ){
        fabR::get_all_na_cols(
          data_dict[['Categories']] %>% select(-.data$`variable`)) %>%
          mutate(sheet    = "Categories")
      }else{tibble()})
  
  if(sum(nrow(data_dict[['Categories']])) > 0){
    
    message("    Assess the presence of categories not in the data dictionary")
    test_existing_variable_category <-
      suppressWarnings(check_data_dict_categories(data_dict)) %>%
      mutate(
        name_col = "variable",
        sheet    = "Categories")
  }
  
  
  if(as_data_dict_mlstr == TRUE){
    
    message(
      "    Assess the completion of `label(:xx)` column in 'Variables'")
    test_var_label <-
      data_dict[['Variables']] %>%
      select(
        .data$`name`,
        label = matches(c("^label$","^label:[[:alnum:]]"))[1]) %>%
      # filter(if_any(-.data$`label`, ~ is.na(.))) %>%
      pivot_longer(
        cols = !.data$`name`,
        names_to = "name_col",
        values_to = "value") %>%
      filter(is.na(.data$`value`)) %>%
      select(name_var = .data$`name`, .data$`name_col`, -.data$`value`) %>%
      mutate(
        name_col = names(
          data_dict[['Variables']] %>%
            select(matches(c("^label$","^label:[[:alnum:]]"))[1])),
        condition =
          paste0(
            "[INFO] - The column `",
            .data$`name_col`,
            "` should exist and not contain 'NA' values")) %>%
      mutate(sheet    = "Variables")
    
    message("    Assess the `valueType` column in 'Variables'")
    test_valueType <-
      check_data_dict_valueType(data_dict) %>%
      mutate(
        name_col = "valueType",
        sheet    = "Variables")
    
    if(sum(nrow(data_dict[['Categories']])) > 0){
      
      message(
"    Assess presence and completion of `label(:xx)` column in 'Categories'")
      test_cat_label <-
        data_dict[['Categories']] %>%
        select(
          .data$`name`,
          label = matches(c("^label$","^label:[[:alnum:]]"))[1]) %>%
        # filter(if_any(-.data$`label`, ~ is.na(.))) %>%
        pivot_longer(
          cols = !.data$`name`,
          names_to = "name_col",
          values_to = "value") %>%
        filter(is.na(.data$`value`)) %>%
        select(name_var = .data$`name`, .data$`name_col`, -.data$`value`) %>%
        mutate(
          name_col =
            names(data_dict[['Variables']] %>%
                    select(matches(c("^label$","^label:[[:alnum:]]"))[1])),
          condition =
            paste0("[INFO] - The column `",
                   .data$`name_col`,
                   "` should exist not contain 'NA' values")) %>%
        mutate(sheet    = "Categories")
      
      test_missing_category <-
        message("    Assess the logical values of missing column in Categories")
      if(as_data_dict_mlstr){
        check_data_dict_missing_categories(data_dict) %>%
          mutate(
            name_col = "missing",
            sheet    = "Categories")}else{tibble()}
    }
  }
  
  # test_var_label
  # test_valueType
  # test_name_standards
  # test_unique_variable
  # test_existing_variable_category
  # test_cat_label
  # test_missing_category
  # test_duplicated_columns
  # # test_duplicated_rows
  # test_empty_row
  # test_empty_col
  
  report$`Data dictionary assessment` <-
    test_name_standards %>%
    bind_rows(test_unique_variable) %>%
    bind_rows(test_duplicated_columns) %>%
    # bind_rows(test_duplicated_rows) %>%
    bind_rows(test_empty_row) %>%
    bind_rows(test_empty_col) %>%
    bind_rows(test_existing_variable_category) %>%
    bind_rows(test_var_label) %>%
    bind_rows(test_valueType) %>%
    bind_rows(test_cat_label) %>%
    bind_rows(test_missing_category) %>%
    
    select(.data$`sheet`,.data$`name_col`,.data$`name_var`,
           `Quality assessment comment` = .data$`condition`) %>%
    arrange(desc(.data$`sheet`),.data$`name_col`,.data$`name_var`) %>%
    mutate(across(everything(), ~ as.character(.))) %>%
    distinct() %>% tibble
  
  message("    Generate report")
  
  if(nrow(report$`Data dictionary assessment`) == 0){
    message("\n    The data dictionary contains no error/warning.")
    report$`Data dictionary assessment` <- NULL
  }
  
  message(bold(
    "
  - WARNING MESSAGES (if any): --------------------------------------------\n"))
  
  return(report)
}

