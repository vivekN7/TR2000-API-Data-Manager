# TR2000 API Data Manager

A professional Blazor Server application for importing and managing data from the TR2000 API.

## Features

- **Data Import**: Import data from TR2000 API endpoints (Operators, Plants, PCS, Issues)
- **SQLite Storage**: Pre-defined database schema for reliable data persistence
- **Data Management**: View, export to CSV, and manage imported data
- **Real-time Progress**: Track import progress with live updates
- **Professional UI**: Clean Bootstrap 5 interface
- **100% Functional**: Ready for production use

## Technology Stack

- **.NET 9.0** (Latest)
- **Blazor Server**
- **SQLite** with Dapper ORM
- **Bootstrap 5**
- **TR2000 API Integration**

## Prerequisites

- .NET 9.0 SDK or later
- Git (for version control)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/vivekN7/TR2000-API-Data-Manager.git
cd TR2000-API-Data-Manager
```

2. Build the solution:
```bash
dotnet build
```

3. Run the database creator (first time only):
```bash
cd DatabaseCreator
dotnet run
cd ..
```

4. Run the application:
```bash
cd TR2KApp
dotnet run --urls "http://localhost:5000"
```

5. Open your browser and navigate to `http://localhost:5000`

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