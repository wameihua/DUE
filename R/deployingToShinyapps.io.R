.installFromGithub =
function(user='professorbeautiful', project=basename(getwd()), ...)
  devtools::install_github(paste0(user, "/", project), ...)


.deploy =
function(app, user='professorbeautiful', project=basename(getwd()),
         reInstall=TRUE, ...){
  ## TODO: first check that the html files are created committed and pushed.
  if(missing(app))
    app = dir('inst')[dir('inst')!='doc'][1]  ## The first folder except for 'doc'.
  packageWD = getwd()
  if(reInstall)
    .installFromGithub(user = user, project = project)
  apps = app
  for (app in apps) {
    if(substr(app, 1, 5) == "inst/")
      warning(".deploy: do not include 'inst' in app name.")
    cat("wd is " , getwd(), "\n")
    setwd(paste0("inst/", app))
    cat("wd changing to ", getwd(), "\n")
    tryCatch({
      rsconnect::deployApp(...)
    },
    finally={
      cat(paste0("rsconnect::showLogs(appPath = 'inst/", app,"')"), '\n')
      setwd(packageWD)
    }
    )
  }
}


.runDeployed =
function(app){
  if(missing(app))
    app = dir('inst')[dir('inst')!='doc'][1]  ## The first folder except for 'doc'.  system(paste0("open https://trials.shinyapps.io/", app))
  browseURL(paste0('https://trials.shinyapps.io/', app))
  cat(paste0("rsconnect::showLogs(appPath = 'inst/", app,"')"), '\n')
}
