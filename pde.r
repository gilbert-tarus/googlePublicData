# Dependencies
require(XML)
require(xlsx)

#archivo <- 'c:/rdspl/series_sc'

checkPath <- function(x, type='output') {
################################################################################
# DESCRIPTION:
# Checks if the output path exists, otherwise stops the routine.
################################################################################  
  ER <- try(setwd(x), silent=T)
  if (class(ER) == 'try-error') {
    stop('Incorrect ', type,' path:\n\t\t\t', x, '\n\t\t couldn\'t be found')
  } 
}

getFilesNames <- function(path, extension='csv') {
################################################################################
# DESCRIPTION:
# As a function of a path and a file extension, gets all the file names there.
################################################################################  
  files <- list.files(path=path,pattern=extension)
  nfiles <- length(files)
  if (nfiles==0) {
    stop(nfiles, ' files found.\nCannot\' continue') 
  }
  else {
    cat(nfiles, 'files found...\n')
  }
  return(files)
}

dsplConfig <- function(path, encoding='UTF-8', ext='csv', output=NA) {
################################################################################
# DESCRIPTION:
# Reads .csv and .xls(x) files, outputs a descriptive dataframe of the data and
# builds a config file.
################################################################################  
  
  checkPath(path, "input")
  
  files <- getFilesNames(path, 'xls')
  
  x <- seekTables(files=files, encoding=encoding, ext=ext)
  x <- unique(
    subset(x,subset=type != 'date' & is.dim.tab==F, 
           select=c(id, label))
    )
  x <- data.frame(x, description=NA, topic=NA)
  if (is.na(output)) {
    return(x) 
  } 
  else {
    ERR<-try(write.table(x, file=output, quote=F, na="___", sep='\t'))
    if (class(ERR)!='try-error') {
      cat('DSPL Configfile written correctly at',output,'\n')
    }
    else {
      cat('An error has occurred during the file writing at',output,'\n')
    }
  }
}

seekTables <- function(files, encoding='UTF-8', ext='csv', output = NA, replace = T) {
################################################################################
# DESCRIPTION:
# Reads .csv and .xls(x) files, exports them as csv and outputs a descriptive da
# taframe. Also determinates which field is dim or metric.
################################################################################  
  
  # Timeframe metrics
  metrics <- matrix(c(
    'dia','day','semana','week','trimestre','quarter', 'mes','month','agno', 
    'year', 'year','year','month','month'), ncol = 2, byrow=T)
  
  # Makes the dir of output
  if (replace & !is.na(output)) {
    output2 <- paste(output,'r_pde',sep='')
    ER <- try(dir.create(path=output2,showWarnings=F), silent=T)
    if (class(ER)=='try-error') {
      stop(paste('Couldn\'t create the folder r_pde in',output2))
    }
    else {
      cat('Output defined', 'Results will be saved at',output2,sep='\n')
    }
    
  } else if (!replace & !is.na(output)) {
    stop(call='Folder already exists, you must make explicit the intention to replace it.')
  }

  vars <- NULL
  vars <- sapply(files,
         function(x,y) {
           # Reads each file, gets the variables names and datatypes
           exts <- matrix(c('csv', ',', 'tab', '\t'),ncol=2,byrow=T)
           if (ext %in% exts[,1]) {
             
             cols <- read.table(
               paste(getwd(),'/',x,sep=''), sep=exts[exts[,1] == ext,2], 
               header=F, nrows=1, encoding=y)
             
             cols <- as.character(cols)
             data <- read.table(x,sep=exts[exts[,1] == ext,2], skip=1, header=F,dec=',')
             colnames(data) <- cols
           } else {
             cols <- read.xlsx(x, sheetIndex=1, header=F,rowIndex=0:1,encoding=y)
             cols <- as.character(cols,deparse=T)
             data <- read.xlsx(x, sheetIndex=1, header=F,rowIndex=2:2000,encoding=y)
           }
           fnames <- x
           for (i in c('.csv','.tab','.xlsx','.xls')) {
            fnames <- gsub(i, '', fnames, fixed=T)
           }
           fnames <- rep(fnames, length(cols))
           
           # Builds descriptive matrix
           var <- c(
             cleantext(cols),
             cols,
             fixType(unlist(lapply(data, typeof))),
             fnames)
           var <- matrix(var, ncol = 4)
           
           # Creates a new column of metric vs dimm
           var <- cbind(var, 'metric')
           
           var[var[,1] %in% metrics[,1], 5] <- 'dimension' # If time
           var[var[,3] %in% 'string',5] <- 'dimension' # If string
           var[var[,1] %in% metrics[,1], 3] <- 'date' # If date
           
           # Identifies which dataset is a dimension dataset
           var <- cbind(var, V6 = F)
           if (all(var[,3] != 'date')) {var[,6] <- T}
           
           # Replaces the date-time colnames for those proper to PDE
           for (i in 1:NROW(metrics)) {cols <- gsub(metrics[i,1], metrics[i,2], 
                                                    cleantext(cols), fixed = T)}
           
           var[,1] <- cols

           vars <- rbind(vars, var)

           # In the case of output, it creates a new folder
           if (!is.na(output)) {
             colnames(data) <- cols
             
             # Sorts the data acording to dimensional concepts (not date)
             ord <- var[var[,5]=='dimension' & var[,3] != 'date',1]
             if (length(ord)!=0) data <- data[do.call(order,data[ord]),]
             
             # Writes the data into csv files
             write.table(x=data, file=paste(output,'/r_pde/',var[1,4],'.csv',sep=''),
               fileEncoding=y, na='', sep=',',quote=F,row.names=F,dec='.')
             cat(x,'analized correctly, ordered by ', ord,' and exported as csv\n')
           }
           else {
             cat(x,'analized correctly\n')
           }
           return(vars)
         }, y=encoding)
  
  # Puts it all into a single matrrx
  vars <- do.call('rbind', sapply(vars, unlist))
  
  # Identifies where are the correspondant tables for each dimension
  vars <- cbind(vars, V7 = NA)
  for (i in 1:NROW(vars)) {
    if (vars[i,5] == 'dimension' & vars[i,3] != 'date' & vars[i,6] != 'TRUE') {
      delta <- try(vars[vars[,1]==vars[i,1] & vars[,6] == 'TRUE',4])
      
      if (length(delta) == 0) {
        stop('Error')
      } else {
        vars[i,7] <- delta
      }
    }
  }
  vars <- data.frame(vars)
  colnames(vars) <- c(
    'id', 'label', 'type', 'slice', 'concept.type', 'is.dim.tab', 'dim.tab.ref'
    )
  return(vars)
}

checkSlices <- function(dims, by) {
################################################################################
# Checks if there's any pair of slices with the same dimentions (error)
################################################################################
  # Builds a list of dims by slice
  slices.dims <- do.call(list,by(dims, by, function(x) unlist(x[order(x)])))
  
  # Generates a list of cohorts (unique) that shouldn't be store more than once
  unique.dims <- unique(slices.dims)
  
  for (i in 1:length(unique.dims)) {
    # Sets the counters
    counter <- 0
    fields <- NULL
    for (j in names(slices.dims)) {
      test <- identical(slices.dims[[j]], unique.dims[[i]])
      
      if (test) {counter <- counter + 1; fields <- paste(fields, j, sep=',')}
      if (counter > 1) {
        stop("Dimention(s) ", unlist(unique.dims[[i]]),
             " apear more than once in the collection at ", fields,
             ". Variables in those tables should be grouped in only one table.")
      }
    }
  }
}

fixType <- function(x) {
################################################################################
# Transforms the datatypes in function of allowed datatypes for DSPL
################################################################################
  replace <- matrix(c('logical', 'integer', 'double', 'complex', 'character',
                      'boolean', 'integer', 'float', 'float', 'string'), ncol =2)
  for (i in 1:5) x <- as.character(gsub(replace[i,1], replace[i,2],x, fixed=T))
  return(x)
}

cleantext <- function(x) {
################################################################################
# Adapts labels to IDs
################################################################################  
  lcase <- matrix(c("á", "a", "é", "e", "í", "i", 'ó', 'o', "ú", "u", "ñ", 
                    "gn", "ý", "y"), ncol = 2, byrow = T)
  
  sym <- matrix(c("$", "money", "°", "grad", "#", "n", "%", "pcent", "…", 
                  "___", " ", "_", ".", "", ",", "_", ";", "_", ":", "_"), 
                ncol = 2, byrow = T)
  
  x <- tolower(x)
  
  for (i in 1:NROW(lcase)) {
    x <- gsub(lcase[i,1], lcase[i,2], x, fixed = T)
  }
  
  for (i in 1:NROW(sym)) {
    x <- gsub(sym[i,1], sym[i,2], x, fixed = T)
  }
  
  return(x)
}

addInfo <- function(nodename,values,parent,lang) {
################################################################################
# Function to add information and provider nodes y multiple languages
################################################################################  
  newXMLNode(nodename, parent=parent, sapply(values, function(x) {
    newXMLNode('value',attrs=c('xml:lang'=lang[which(values==x)]), x,
               suppressNamespaceWarning=T)}))
}

addConcepts <- function(val,parent,lang) {
################################################################################
# Function to create and populate the concepts
################################################################################  
  colnames(val)[3] <- 'ref'
  if (NCOL(val) > 1) {
    fun <- function(x, ...) {apply(x, MARGIN = 1,...)}
  } else {
    fun <- function(x, FUN) {FUN(x)}
  }
  
  fun(val, FUN= 
    function(x) {
      #x <- as.character(x)
      if (x['ref'] == 'string') {ATT <- c(x['id'], extends='entity:entity')}
      if (x['ref'] != 'string') {ATT <- c(x['id'])}
      
      # in the case of not being a dimensional concept
      if (x['concept.type']!='dimension') {
        newXMLNode('concept', attrs=ATT, parent=parent,newXMLNode('info',newXMLNode(
          'name', newXMLNode('value', attrs=c('xml:lang'=lang[1]), suppressNamespaceWarning=T,
                             x['label']))), newXMLNode('type', attrs=c(x['ref']))
                   )
      } else {
        # in the case of being a dimensional concept
        newXMLNode('concept', attrs=ATT, parent=parent,newXMLNode('info',newXMLNode(
          'name', newXMLNode('value', attrs=c('xml:lang'=lang[1]), suppressNamespaceWarning=T,
                             x['label']))), newXMLNode('type',attrs=c(x['ref'])),
                   newXMLNode('table', attrs=c(ref=paste(x['dim.tab.ref'],'_table',sep='')))
                   )
      }
    }
      )
}

addSlices <- function(tableid, sliceatt, parent) {
################################################################################
# Function to create and populate the slices
################################################################################
  colnames(sliceatt)[1] <- 'concept'
  by(data=sliceatt, INDICES=tableid,FUN=
    function(x) {
      newXMLNode(name='slice', attrs=c(id=paste(x$slice[1],'_slice',sep='')),
                 parent=parent, apply(x, MARGIN = 1,FUN=
                   function(z){
                     #z <- as.character(z)
                     # In the case of dates-time
                     if (z['type'] == 'date') {
                       newXMLNode(name=z['concept.type'], 
                                  attrs=c(concept=paste('time:',z['concept'],sep='')))
                       # Otherwise
                     } else {
                       newXMLNode(name=z['concept.type'], attrs=c(z['concept']))
                     }}), newXMLNode('table', attrs=c(ref=paste(x$slice[1],'_table',sep=''))))
    }
    )
}

addTables <- function(tableid, tableatt, parent, format) {
################################################################################
# Function to create and populate the tables
################################################################################
  by(data=tableatt, INDICES=tableid,FUN=
    function(x) {
      newXMLNode(name='table', attrs=c(id=paste(x$slice[1],'_table',sep='')),parent=
        parent, apply(X=x, 
                      MARGIN = 1, FUN=
                        function(z){
                          if (z['type'] == 'date') {
                            newXMLNode(name='column', attrs=c(z['id'], z['type'], format=format))  
                          } else {
                            newXMLNode(name='column', attrs=c(z['id'], z['type']))
                          }}), newXMLNode(name='data', newXMLNode('file', attrs=c(format=
                            'csv', encoding='utf8'),paste(x$slice[1],'.csv',sep='')))
                 )
    }
     )
}

pde <- function(
################################################################################
# DESCRIPTION:
# Based on an specific folder directory, the function seeks for files that match
# the specified extension (csv, tab, xls, xlsx), reads the column names, guesses
# the datatype and outputs a dspl metadata file including the corresponding csv
# files
#
# VARIABLES:
# - path: Full path to the folder where the tables are saved.
# - Output: FUll path to the output folder (pde will create a subfolder call r_dspl).
# - replace: In the case of defining output, replaces the files.
# - targetNamespace:
# - timeFormat: The corresponding time format of the collection.
# - lang: A list of the languages supported by the dataset.
# - name: The name of the dataset.
# - description: The dataset description.
# - url: The corresponding URL for the dataset.
# - providerNAme
# - providerURL
# - extension: The extension of the tables in the 'path' folder.
# - encoding: The char encoding of the input tables.
# - fileEncoding: The tables files encoding.
################################################################################  
  path,
  output = NA,
  replace = F,
  targetNamespace = '',
  timeFormat = 'yyyy',
  lang = c('es', 'en'),
  name = NA,
  description = NA,
  url = NA,
  providerName = NA,
  providerURL = NA,
  extension = 'csv',
  encoding = 'UTF-8',
  fileEncoding = 'UTF-8'
  ) {
  # Depuracion de Errores
  
  
  description <- ifelse(!is.na(description),description,'No description')
  name <- ifelse(!is.na(name),name,'No name')
  providerName <- ifelse(!is.na(providerName),providerName,'No provider')
  
  # Parametros iniciales
  options(stringsAsFactors=F)
  
  # Checking if output path is Ok
  checkPath(output, "output")
  checkPath(path, "input")
  
  # Gets the filenames
  files <- getFilesNames(path, extension) 
  
  # Variables Lists and datatypes
  vars <- seekTables(files, encoding, extension, output, replace)
  dims <- subset(vars, concept.type=='dimension', select=c(id, slice, concept.type))
  
  # Identifying if there is any duplicated slice
  checkSlices(dims=dims$id, by=dims$slice)
  
  # Creates a unique concept list
  varConcepts <- unique(
    subset(vars,subset=type != 'date' & is.dim.tab==F, select=-slice)
    )
  
  # Armado de xml
  archXML <- newXMLDoc()
  dspl <- newXMLNode(name='dspl', doc=archXML, attrs=c(
    targetNamespace=targetNamespace), namespace=c(xsi=
      'http://www.w3.org/2001/XMLSchema-instance'))
  
  try(xmlAttrs(dspl)['xmlns'] <- 'http://schemas.google.com/dspl/2010', silent=T)
  
  # Definiciones dspl
  
  imports <- c('quantity', 'entity', 'geo', 'time', 'unit')
  
  sapply(imports,
         function(x) {
           newXMLNamespace(node=dspl, prefix=x,namespace=paste(
             'http://www.google.com/publicdata/dataset/google/',x,sep=''))
         })
  # Concepts import lines
  newXMLCommentNode('Lineas de importacion de conceptos', parent=dspl)
  
  imports <- paste(
    "http://www.google.com/publicdata/dataset/google/",
    imports, sep = '')
  
  sapply(X = imports,
         FUN = function(x) newXMLNode(attrs=c(namespace=x), name = 'import',
                                      parent = dspl))
  # INFO
  newXMLCommentNode('Lineas de informacion', parent=dspl)
  info <- newXMLNode('info', parent = dspl)
  addInfo('name', name, info, lang)
  addInfo('description', description, info, lang)
  if (!is.na(url)) newXMLNode('url', newXMLNode('value', url), 
                              parent = info)
  
  # PROVIDER
  newXMLCommentNode('Lineas del proveedor de datos', parent=dspl)
  provider <- newXMLNode('provider', parent = dspl)
  addInfo('name', providerName, provider, lang)
  if (!is.na(providerURL)) newXMLNode('url', newXMLNode('value', providerURL), 
                                      parent = provider)
  
  # TOPICS
  
  # CONCEPTS
  newXMLCommentNode('Concepts Def', parent=dspl)
  concepts <- newXMLNode('concepts', parent = dspl)
  addConcepts(varConcepts,concepts, lang)
  
  # SLICES
  newXMLCommentNode('Slices Def', parent=dspl)
  slices <- newXMLNode('slices', parent = dspl)
  addSlices(
    tableid=subset(vars, is.dim.tab != T, slice),
    sliceatt=subset(vars, is.dim.tab != T),
    parent=slices
    )
  
  # TABLES
  newXMLCommentNode('Tables Def', parent=dspl)
  tables <- newXMLNode('tables', parent = dspl)
  addTables(tableid=vars$slice,tableatt=vars,parent=tables, format=timeFormat)  
  
  # If an output file is specified, it writes it on it
  if (is.na(output)) {
    result <- structure(.Data=list(saveXML(archXML, encoding = 'UTF-8'),vars),
                        .Names=c('xml', 'variables'))
    return(result)
  
  } else {
    result <- file(paste(output,'/r_pde/metadata.xml',sep=''), encoding='UTF-8')
    cat(saveXML(archXML, encoding='UTF-8'), file=result)
    close.connection(con=result)
    return(paste('Metadata created successfully at ',output, 
                 'r_dspl/metadata.xml',sep=''))
  }
  
}