# Git and Qlik

Here's my notes on how I'd like to use Qlik with Git. This can eventually form part of the docs for a skeleton project.

## Why use Git with Qlik?

Potentially, Git can provide the techincal framework for collaborating on a single Qlikviw project in an agile way. Devs could work on the same document simultaneously, and have changes to the same document merged by git to manage conflicts when working on the same file. Futhermore, milestones and releases could be tagged and rolled back more easily, and branches could be used to work on new features/refactoring without affecting the main application.

## Challenges

There are several challenges to using Git with qlikview, but the central one is that Qlik's main file format for projects - the QVW, combines both data, load script and layout in a single binary file. This makes it impossible to merge changes on a QVW directly, and also drastically increases the file size for projects with even a moderate amount of data. As a result, we need a considered approach to what parts of the project should be managed by version control and which should not.

### Ignore Data

Regarding the above, the first choice we need to make is to ignore the data within a QVW and only track changes on the load script and layout. We could do this in several ways, each of which has advantages and drawbacks.

### Option 1: Removing data and saving QVWs

This is a basic option that uses qlikview's reduce data feature (or the /nodata command line flag) to drop all the data from a qvw, after which it can be saved, providing a much smaller file. However, this still results in us tracking a binary file, which cannot be diffed or merged, and so is a poor solution for collaborating and tracking changes.

### Option 2: Explicitly separating load script and exporting layout

In order to get separate file for the projects layout and load script, we could do the following:

* To separate the load script, the whole script can be stored as a qvs file and then referenced in an include statement within the qvw, no other data should be stored in the qvw.
* To separate the layout, qlik supports exporting the document layout via _File -> Export -> Export Document Layout_ This exports the document layout as XML files to a folder. These can also be re-imported, however this is a manual process rather than an automatic one.

This method captures the most important parts of a project in text format, but is a manual process rather than an automatic one - new documents must be explicity set to load qvs scripts, and layouts must be manually imported when checking out from the repository. As a result it falls short of making version control simple and easy to manage.

### Option 3: -prj Folders

Prj Folders are Qliks way of trying to make version control in Qlik more achievable, and whilst not officially supported by Qlik, offer probably the best way to implement version control with Git in Qlik. Once a PRJ folder for a qvw is created (by creating a folder with the name [QVW_NAME]-prj within the same directory as the qvw), qlik will populate this folder with the data neccessary to re-create the qvw in text format, including the load script, layout, and variables. Population of the prj folder is automatic upon saving the qvw, and any changes to the prj folder to the prj folder will be applied to the qvw when it is opened. It is worth noting that the prj folder is _not_ the project itself, the qvw still contains all everything it needs to function without the prj folder and can be migrated to another directory independently. Rather, the prj folder is applied on top of the qvw on opening to update it with any changes.

The prj folder does have some limitations:
* It is not officially supported by qlik. If it breaks your project, you are on your own.
* Object ID's must not be altered, or reconstruction from the prj folder may fail and take your qvw with it.

## A combined approach.

The approach I'm currently favouring is a combined one that mainly uses the prj approach, along with backing up some qvws as insurance against prj folder corruption. For the most part, we rely on the prj folder to track our changes. However, in case this ever fails, I also want to maintain a version of certain qvw's (spcifically the main application, since our qvd loaders are most likely just empty shells with script in them anyway) with the data removed, that can serve as a backup of the document state in case reconstruction from the prj folder fails.

## Directory Structure

The directory structure I've chosen is based on my normal non-version controlled folder structure. I've assumed a two-tier application structre here with one or more extract/transform layers saving data to a QVD folder, which is then loaded into the front end applciation.

```
Project (root of git repo)
  |---- StaticFiles (Non-qvd source data goes here if it needs to be stored with the application. Excel files, CSVs etc.)
  |---- QVD (QVD Files go here, front end application should only load from this directory)
  |---- QVDLoader
  |       |---- ConnectString1.qvs
  |       |---- Loader1.qvw
  |       |---- Loader1.nd.qvw (No data version of Loader1).
  |       |---- Loader1-prj (And contents)
  |---- MyApp (Name of application)
  |       |---- MyApp.qvw
  |       |---- MyApp.nd.qvw  (No data version of MyApp).
  |       |---- MyApp-prj (And contents)
  |
  |---- .gitignore
  |---- ...any other files - docs, 
``` 

## .gitignore

The .gitignore file defines which files should be ignored from verison control, this is important to us because we have several file types that we don't want git to track:

* We don't want to track our actual qvw files.
* We _do_ want to track our .nd.qvw files with the data removed.
* We don't want to track any data, this includes our QVD and StaticFiles Folders.
* We also dont want to track a few other file types (log files, tmp files etc.)

> It's possible we may want to track some data files, perhaps a simple mapping table created as part of the project that is shared by several qvws, or some other simple files. In general though we should avoid tracking data, and if possible store it separately from the application itself in some commonly accessible location.

With that in mind see the gitignore file in the files below.

## Procedural Data Reduction:

Whilst Qlik has a command line flag to open a qvw without data, it does not have one that saves the qvw in this state. This means we will have to find a different way to save a reduced qvw. Whilst I generally try and avoid vb script, it does solve this problem - see reduce.vbs for how. The script loops through the App and QVDLoader files, and opens each qvw in turn, then does the following:

* Checks for a corresponding prj folder. If none exists, it asks the user if one should be created, then creates one and saves the qvw to populate it's contents.
* Drops the data from the qvw and saves a copy with the extension ".nd.qvw".
* Quits and moves on to the next file.

The script thus takes care of two concerns, firstly making sure that prj folders have been genrated for all of our qvw files, and secondly that there is an up-to-date reduced copy.

> Note: In future I'd like to make this step part of a pre-commit hook, so that it can be run automatically before each commit. For now the user must run it themselves.

## Qlikview Features Supported

 Feature | Captured by PRJ | Captured by .nd.qvw  
 ----- |:-----:| :-----:
 Load Script | x | x
 Layout | x | x
 Variables | ? | ?
 Field Event Triggers | ? | ?
 Variable Event Triggers | ? | ?
 Document Event Triggers | ? | ?
 
 
 
 
