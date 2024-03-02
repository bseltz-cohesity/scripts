USE [msdb]
GO

/****** Object:  Job [Clone DB]    Script Date: 2/10/2022 3:43:40 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 2/10/2022 3:43:40 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Clone DB', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'MYDOMAIN\sqlagent', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Teardown Old Clone]    Script Date: 2/10/2022 3:43:40 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Teardown Old Clone', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe C:\scripts\powershell\destroyClone.ps1 -vip mycluster -username myuser -domain mydomain.net -cloneType sql -dbName clonedb -dbServer sqldev.mydomain.net -wait', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Clone Masked DB]    Script Date: 2/10/2022 3:43:40 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Clone Masked DB', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command c:\scripts\powershell\cloneSQL.ps1 -vip mycluster -username myuser -domain mydomain.net -sourceServer sqlprod.mydomain.net -sourceDB proddb -targetServer sqldev.mydomain.net -targetDB clonedb -wait', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
