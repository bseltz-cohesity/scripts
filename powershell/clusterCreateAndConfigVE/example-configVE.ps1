./configVE.ps1 -vip 10.19.0.201 `
               -pwd 'thatsSomePassword!' `
               -adminEmail 'admin@mydomain.net' `
               -adDomain 'sa.corp.cohesity.com' `
               -adAdmin mrMicrosoft `
               -adPwd swordfish `
               -adOu Servers/Cohesity `
               -preferredDC 'sac-infr-dc-01.sa.corp.cohesity.com', 'sac-infr-dc-02.sa.corp.cohesity.com' `
               -adAdminGroup 'Domain Admins' `
               -timeZone 'America/New_York' `
               -smtpServer 'mail.sa.corp.cohesity.com' `
               -supportPwd 'thisIsTheSupportPassword!' `
               -alertEmail 'alerts@mydomain.net'


