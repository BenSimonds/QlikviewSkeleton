' This script loops through the App and QVDLoader Folders and converts any QVWs to reduced ones. 
' Currently it isn't recursive. Logs to reduce.vbs.log

'Create filesystem object'
Set objFSO = CreateObject("Scripting.FileSystemObject")

'Set Working Directory for relative paths.'
WorkingDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
'Create Logfile'
Set myLog = objFSO.CreateTextFile(WorkingDir & "\reduce.vbs.log")
mylog.WriteLine Now &" Begin logging..."

'Look in App and QVD Loader and reduce files:'
Set QVWPaths = CreateObject("Scripting.Dictionary")
QVWPaths.Add objFSO.GetFolder(WorkingDir & "\App"), ""
QVWPaths.Add objFSO.GetFolder(WorkingDir & "\QVDLoader"), ""
'ADD OTHER FOLDERS TO BE SEARCHED HERE'

'Loop through folders'
mylog.WriteLine Now & " Looping through Folders"

For Each QVWPath in QVWPaths.Keys()
	mylog.WriteLine Now & " Searching in: " & QVWPath

	For Each QVWFile in QVWPath.Files
		If UCase(objFSO.GetExtensionName(QVWFile.Name)) = "QVW" AND UCase(Right(QVWFile,7)) <> ".ND.QVW" Then
			mylog.WriteLine Now & " Found QVW: " & QVWFile.Name
			ReduceData QVWFile
		End If
	Next
	
 Next


mylog.WriteLine Now & " Finished!"

'----------------SUBROUTINES----------------'

Sub ReduceData(QVW)
	'Source and destination file paths'
	BaseName = Left(QVW,Len(QVW)-4)
	Target = BaseName & ".nd.qvw"
	PRJFolder = BaseName & "-prj"
	mylog.WriteLine Now & " Creating No Data File: " & QVW & " >> " & Target

	'Open File in Qlik'
	Set MyApp = CreateObject("QlikTech.QlikView")
	Set MyDoc = MyApp.OpenDoc(QVW,"","")
	mylog.WriteLine Now & " 	...File Opened."
	
	'I hate it when generate logfile isn't turned on, so here I make sure it's done for every file.
	set docProp = MyDoc.GetProperties 		'Creates a properties object'
	If not docProp.GenerateLogfile:
		docProp.GenerateLogfile = true 			'Sets GenerateLogfile to true'
		MyDoc.SetProperties docProp 			'Sets DocProperties to our modified object.'
		MyDoc.SaveAs(QVW)				'Saves the doc.'
	End If
	set docProp = Nothing

	'Test prj folder exists:'
	If not objFSO.FolderExists(PRJFolder) Then
		mylog.WriteLine Now & "PRJ  folder not found for " & BaseName
		result = MsgBox ("PRJ  folder not found for " & BaseName & ". Create?", vbYesNo, "Yes No Example")

		Select Case result
		Case vbYes
		    'Create PRJ Folder and populate by saving.'
		    mylog.WriteLine Now & " 	...Creating PRJ  folder: " & PRJFolder
			Set objFolder = objFSO.CreateFolder(PRJFolder)
			mylog.WriteLine Now & " 	...Populating PRJ  folder: " & PRJFolder
		    MyDoc.SaveAs(QVW)
		    
		Case vbNo
			'Do Nothing...'
			mylog.WriteLine Now & " 	...Doing nothing."
		    WScript.Sleep(1)
		End Select

	End IF

	'Remove Data and Save'
	MyDoc.RemoveAllData
	mylog.WriteLine Now & " 	...Data Reduced."
	
	MyDoc.SaveAs(Target)
	mylog.WriteLine Now & " 	...File Saved."

	WScript.Sleep(1000) 'Qlikview thinks it has crashed if it closes too quickly...'
	MyDoc.GetApplication.Quit
	mylog.WriteLine Now & " 	...App Quit."

	'Quit'
	Set MyDoc = Nothing
	Set MyApp = Nothing
	mylog.WriteLine Now & " 	...Vars Dropped."

END SUB

