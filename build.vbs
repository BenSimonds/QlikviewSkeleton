
' This script loops through the App and QVDLoader Folders and converts any reduced QVWs to real ones. 
' It is the inverse operation to reduce.vbs

'Create filesystem object'
Set objFSO = CreateObject("Scripting.FileSystemObject")

'Set Working Directory for relative paths.'
WorkingDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
'Create Logfile'
Set myLog = objFSO.CreateTextFile(WorkingDir & "\build.vbs.log")
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
		If UCase(Right(QVWFile,7)) = ".ND.QVW" Then
			mylog.WriteLine Now & " Found No Data QVW: " & QVWFile.Name
			Source = QVWFile
			Destination = objFSO.GetFolder(QVWPath) & "\" & Left(objFSO.GetBaseName(QVWFile),Len(objFSO.GetBaseName(QVWFile))-3) & ".qvw"
			mylog.WriteLine Now & " Generating qvw: " & Destination
			objFSO.CopyFile Source, Destination
			GenQVW Destination
		End If
	Next
	
 Next


mylog.WriteLine Now & " Finished!"

'----------------SUBROUTINES----------------'

Sub GenQVW(QVW)
	'Source and destination file paths'
	mylog.WriteLine Now & " Creating Full QVW File: " & QVW 

	'Open File in Qlik'
	Set MyApp = CreateObject("QlikTech.QlikView")
	Set MyDoc = MyApp.OpenDoc(QVW,"","")
	mylog.WriteLine Now & " 	...File Opened."

	'Save and close.'
	MyDoc.SaveAs(QVW)
	mylog.WriteLine Now & " 	...File Saved."

	WScript.Sleep(1000) 'Qlikview thinks it has crashed if it closes too quickly...'
	MyDoc.GetApplication.Quit
	mylog.WriteLine Now & " 	...App Quit."

	'Quit'
	Set MyDoc = Nothing
	Set MyApp = Nothing
	mylog.WriteLine Now & " 	...Vars Dropped."

END SUB

