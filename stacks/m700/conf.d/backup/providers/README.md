# Providers

This directory contains configuration files (`.env`) for different backup providers.  
Each `.env` file stores credentials and settings required to connect to a specific backup destination, such as S3, Backblaze B2, or other cloud storage services.

## Usage

- Place a separate `<name>.env` file for each provider in this directory.
- The backup scripts will source these files to load the necessary environment variables for authentication and configuration.

## Example

**`s3.env`:**
```env
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

OBJECT_STORAGE_API=
```

**`b2.env`:**
```env
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

OBJECT_STORAGE_API=
```

## Notes

- Use one `.env` file per provider for clarity and separation of credentials.
- The backup script will iterate over all `.env` files in this directory and perform backups for each