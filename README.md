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

Prj Folders are Qliks way of trying to make version control in Qlik more achievable, and whilst not officially supported by Qlik, offer probably the best way to implement version control with Git in Qlik. Once a PRJ folder for a qvw is created (by creating a folder with the name [QVW\_NAME]-prj within the same directory as the qvw), qlik will populate this folder with the data neccessary to re-create the qvw in text format, including the load script, layout, and variables. Population of the prj folder is automatic upon saving the qvw, and any changes to the prj folder to the prj folder will be applied to the qvw when it is opened. It is worth noting that the prj folder is _not_ the project itself, the qvw still contains all everything it needs to function without the prj folder and can be migrated to another directory independently. Rather, the prj folder is applied on top of the qvw on opening to update it with any changes.

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
  |---- ...any other files - docs

``` 

## .gitignore

The .gitignore file defines which files should be ignored from verison control, this is important to us because we have several file types that we don't want git to track:

* We don't want to track our actual qvw files.
* We _do_ want to track our .nd.qvw files with the data removed.
* We don't want to track any data, this includes our QVD and StaticFiles Folders.
* We also dont want to track a few other file types (log files, tmp files etc.)

> It's possible we may want to track some data files, perhaps a simple mapping table created as part of the project that is shared by several qvws, or some other simple files. In general though we should avoid tracking data, and if possible store it separately from the application itself in some commonly accessible location.

See `.gitignore` for the full list of ignored files..

## Local Variables:

A typical problem that might arise when managing a project across different environments is the need to have some local variables. If the location of our data set on one machine  is `C:\Data` and on another is `D:\Data` we want to be able to set this locally without git overriding each location's settings every time we push a commit to the repository. But we also want to have sane defaults for these variables, so that we know how to set them up in the first place. To deal with this I create two .qvs files: `globals.qvs` and `locals.qvs`. When loaded in order (globals then locals), they can be used to set defaults for any qvw that needs them. By default locals.qvs can be left empty, variables only need overwriting when they should differ from the global value.

In the below example, use this to set a variable to hide some developer sheets from the end user. The `vShowSummarySheet` variable on the other hand will be left at the default value.

globals.qvs
```
  let vShowSummarySheet  = 1; // Show/Hide condition for summary sheet.
  let vShowDevSheets = 0; // Dont show dev sheets by default.
```

locals.qvs
```
  let vShowDevSheets = 1; //Show dev sheets on this repo. 
```
Snippet of load script
```
  //Load Global and Local Variables:
  $(Include=..\globals.qvs);
  $(Include=..\locals.qvs); // Overwrites variable set by globals.qvs
```
`Locals.qvs` is then added to gitignore.

## Scripts:

I've started working on some useful scripts to help with maintaining the project through different processes, namely data reduction (pre-commit) and qvw generation (after cloning/pulling when no actual qvw's exist).

### Data Reduction: `reduce.vbs`

Whilst Qlik has a command line flag to open a qvw without data, it does not have one that saves the qvw in this state. This means we will have to find a different way to save a reduced qvw. Whilst I generally try and avoid vb script, it does solve this problem - see `reduce.vbs` for how. The script loops through the App and QVDLoader files, and opens each qvw in turn, then does the following:

* Checks for a corresponding prj folder. If none exists, it asks the user if one should be created, then creates one and saves the qvw to populate its contents.
* Drops the data from the qvw and saves a copy with the extension `.nd.qvw`.
* Quits and moves on to the next file.

The script thus takes care of two concerns, firstly making sure that prj folders have been genrated for all of our qvw files, and secondly that there is an up-to-date reduced copy.

> Note: In future I'd like to make this step part of a pre-commit hook, so that it can be run automatically before each commit. For now the user must run it themselves.

### QVW Generation: `build.vbs`

Once we've made commits to our project and pushed them to a repository, and then cloned that repository somewhere else, we also need to run the data reduction process in reverse. Since none of our actual qvw files are copied across (just stripped .nd.qvw files). We need to re-generate them when we clone the repository. This can be split into two parts:
  
  * Creating MyApp.qvw from MyApp.nd.qvw and refreshing it from the prj folder (though it should be up to date anyway) and re-saving it.
  * Reloading MyApp.qvw

The former task is more important than the latter, as you may wish to do the latter in several different ways depending on the application (running a chain of tasks in publisher, batch file, manually). The first task is carried out by `build.vbs`. It performs the following steps in a very similar way to `reduce.vbs`:

  * Loops through App and QVDLoader and for each `.nd.qvw` file it finds, copies it to create a `.qvw` file.
  * Opens that qvw file to cause QlikView to apply the -prj folder, saves and closes.

Doing this without worrying about reloading saves having to worry about dependencies between files. Reloads can then be done whichever way the user chooses.

## Qlikview Features Supported

Feature | Captured by PRJ | Captured by .nd.qvw | Comments
----- |:-----:| :-----:|:-----
Load Script | Yes | Yes |
Layout | Yes | Yes |
Variables | Yes | Yes |
Bookmarks | Yes | Yes | Stored in DocInternals.xml
Field Event Triggers | Yes | Yes | Stored in AllProperties.xml
Variable Event Triggers | Yes | Yes | Stored in AllProperties.xml
Document Event Triggers | Yes | Yes | Stored in DocProperties.xml
Selection State | *No*  | *No* | Not stored in prj, .nd.qvw loses data (and therefore selections within).
 
## Branching Model

The branching model you adopt has a significant impact on how you manage your project and your repository. There are several well known branching models, two key ones being [git-flow](http://nvie.com/posts/a-successful-git-branching-model/) and [GitHub Flow](https://guides.github.com/introduction/flow/). I haven't used either in anger, so I don't have a strong opinion yet on which is best to use, but I'm inclined towards the relative simplicity of GitHub Flow. In the GitHub Flow model you create a branch for each feature or fix you work on, then commit this back to master once you've finished implementing and testing this. This has the advantage of always keeping `master` in a deployable state. It also requires you to manage fewer branches than git-flow and provides a easy way to do code review if you're using a tool like GitHub or Bibucket (via putting in a pull request to merge your branch).

## Merge Conflicts

Because XML content can be difficult to diff intelligently, git can sometimes give us misleading conflicts. Consider the following diff:
 
 ```diff
 @@ -100,11 +100,11 @@
           <ZedLevel>0</ZedLevel>
         </PrjFrameParentDef>
         <PrjFrameParentDef>
-          <ObjectId>Document\CH04_131517295</ObjectId>
+          <ObjectId>Document\CH02_985394347</ObjectId>
           <Rect>
-            <Left>1938</Left>
-            <Top>1322</Top>
-            <Width>934</Width>
+            <Left>1016</Left>
+            <Top>1175</Top>
+            <Width>769</Width>
             <Height>900</Height>
           </Rect>
           <MinimizedRect>
 ```
