# Providers

This directory contains configuration files (`.env`) for different backup providers.  
Each `.env` file stores credentials and settings required to connect to a specific backup destination, such as S3, Backblaze B2, or other cloud storage services.

## Usage

- Place a separate `<name>.env` file for each provider in this directory.
- The backup scripts will source these files to load the necessary environment variables for authentication and configuration.

## Example

**`s3.env`:**
```env
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
RESTIC_REPOSITORY=s3:s3.amazonaws.com/your-bucket/path
RESTIC_PASSWORD=your-restic-password
```

**`b2.env`:**
```env
B2_ACCOUNT_ID=your-account-id
B2_ACCOUNT_KEY=your-account-key
RESTIC_REPOSITORY=b2:your-bucket:path
RESTIC_PASSWORD=your-restic-password
```

## Notes

- Use one `.env` file per provider for clarity and separation of credentials.
- The backup script will iterate over all `.env` files in this directory and perform backups for each