-- Step 1: Create a self-signed certificate
CREATE CERTIFICATE TDE_Cert
WITH SUBJECT = 'TDE_Certificate';

-- Step 2: Backup the certificate to a file with a private key
-- Specify the file paths and passwords
DECLARE @CertificateBackupPath NVARCHAR(200) = '/TDE_Cert_Backup.cer'; -- Path to backup the certificate
DECLARE @PrivateKeyBackupPath NVARCHAR(200) = '/TDE_Cert_PrivateKey.pvk'; -- Path to backup the private key
DECLARE @PrivateKeyPassword NVARCHAR(50) = 'Td3$trongPwd1'; -- Password for the private key

-- Backing up the certificate and private key
BACKUP CERTIFICATE TDE_Cert
TO FILE = @CertificateBackupPath
WITH PRIVATE KEY (
    FILE = @PrivateKeyBackupPath,
    ENCRYPTION BY PASSWORD = @PrivateKeyPassword
);

-- Output the paths for confirmation
SELECT @CertificateBackupPath AS CertificatePath, @PrivateKeyBackupPath AS PrivateKeyPath;
