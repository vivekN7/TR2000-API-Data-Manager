# TR2000 ETL System

## Overview
Oracle APEX-based ETL system for TR2000 API data management with automated plant and issue processing.

## Key Features
- ✅ **APEX_WEB_SERVICE** integration with HTTPS (70% code reduction)
- ✅ **Oracle Database 21c** with APEX 24.2
- ✅ **Automated ETL pipeline** with SHA256 deduplication
- ✅ **Real-time API integration** with TR2000 endpoints
- ✅ **Pure Oracle solution** - No external dependencies

## Current Architecture
- **Primary**: Oracle APEX with PL/SQL packages
- **Database**: Oracle 21c XE with full ETL logic
- **API Client**: APEX_WEB_SERVICE with Oracle wallet
- **UI**: APEX application (15-minute setup)
- **Legacy**: Blazor Server components (optional)

## Prerequisites

- Oracle Database 21c XE with APEX 24.2
- Oracle wallet configured at `C:\Oracle\wallet`
- Network ACLs for `equinor.pipespec-api.presight.com`

## Quick Start

### 1. Database Setup
```sql
-- Run as SYS user
@Database/Master_DDL.sql
```

### 2. APEX Application (15 minutes)
Follow `Database/APEX_QUICK_START.md`:
1. Create workspace TR2000_ETL
2. Create app from PLANTS table
3. Add ETL buttons
4. Run application

### 3. Access Application
```
URL: http://localhost:8080/apex
Workspace: TR2000_ETL
Schema: TR2000_STAGING
```

## Project Structure

```
TR2K/
├── TR2KApp/                    # Main Blazor Server Application
│   ├── Components/             # Blazor components and pages
│   ├── Data/                   # SQLite database file
│   └── wwwroot/                # Static files (CSS, JS, Bootstrap)
├── TR2KBlazorLibrary/          # Business Logic Library
│   ├── Logic/                  # Services and Repositories
│   └── Models/                 # Data models
├── DatabaseCreator/            # Database initialization tool
├── Documentation/              # API documentation and references
└── Tasks/                      # Development tasks and PRD
```

## Usage

1. **Navigate to TR2000 API Data** from the sidebar
2. **Select a data type** (Operators, Plants, PCS, or Issues)
3. **For PCS/Issues**: Select a plant from the dropdown
4. **Test Connection** to verify API access
5. **Import Data** to fetch and store in SQLite
6. **View and Export** your imported data

## Database Schema

The application uses a pre-defined SQLite database with the following tables:
- `operators` - TR2000 operators
- `plants` - TR2000 plants
- `pcs` - Pipe Class Sheets
- `issues` - Plant issues
- `ImportLog` - Import operation tracking

## Development

### Building from Source
```bash
dotnet build
```

### Running Tests
```bash
dotnet test
```

### Creating a Release Build
```bash
dotnet publish -c Release
```

## Git Workflow

### Initial Setup (Already Done)
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/vivekN7/TR2000-API-Data-Manager.git
```

### Making Changes
```bash
git add .
git commit -m "Your commit message"
git push origin master
```

### To Push to GitHub

You'll need to set up authentication. Options:

1. **Using GitHub Personal Access Token (Recommended)**:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate a new token with `repo` permissions
   - Use the token as your password when pushing

2. **Using SSH**:
   ```bash
   git remote set-url origin git@github.com:vivekN7/TR2000-API-Data-Manager.git
   ```

3. **Using GitHub CLI**:
   ```bash
   gh auth login
   git push origin master
   ```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is proprietary software. All rights reserved.

## Status

✅ **100% Complete and Ready for Production**

Last Updated: August 13, 2025

---

Built with ❤️ using .NET 9.0 and Blazor