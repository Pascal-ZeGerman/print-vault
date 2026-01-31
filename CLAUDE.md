# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Print Vault is a self-hosted 3D printing management system with a Django REST Framework backend and Vue.js frontend. The application is containerized with Docker and designed as a Progressive Web App (PWA) for mobile-first inventory management.

**Stack:**
- Backend: Django 5.2.4 + Django REST Framework 3.16.0
- Frontend: Vue 3.5 + Vite 7.0
- Database: PostgreSQL 15 (production), SQLite (development)
- Deployment: Docker Compose

## Development Commands

### Backend (Django)

Development server (bare metal - runs in external terminal):
```bash
# DO NOT run these - user runs them in external PowerShell
python manage.py runserver
python manage.py migrate
python manage.py makemigrations
```

Run tests:
```bash
# Full test suite
pytest

# Run specific test file
pytest inventory/tests/test_models.py

# Run specific test class
pytest inventory/tests/test_models.py::TestInventoryItemModel

# Run specific test
pytest inventory/tests/test_models.py::TestInventoryItemModel::test_create_item

# Run with coverage
pytest --cov=inventory --cov-report=html

# Run tests by marker
pytest -m unit           # Only unit tests
pytest -m integration    # Only integration tests
pytest -m "not slow"     # Skip slow tests
```

### Frontend (Vue/Vite)

Development server (bare metal - runs in external terminal):
```bash
cd frontend
# DO NOT run these - user runs them in external PowerShell
npm run dev
npm install
```

Production build:
```bash
cd frontend
npm run build
```

Linting and formatting:
```bash
cd frontend
npm run lint      # ESLint with auto-fix
npm run format    # Prettier
```

Frontend tests:
```bash
cd frontend
npm run test              # Run Vitest tests
npm run test:ui           # Run with UI
npm run test:coverage     # Run with coverage
```

### Docker (Production)

**Note:** Docker commands CAN be run by Claude. Dev servers run in external terminals.

```bash
# Build and start all services
docker compose up --build -d

# Rebuild with no cache (for upgrades)
docker compose down
docker compose up -d --build --no-cache

# View logs
docker compose logs backend --tail 50
docker compose logs frontend --tail 50

# Restart services
docker compose restart backend
docker compose restart frontend

# Stop all services
docker compose down

# Execute commands in containers
docker compose exec backend python manage.py migrate
docker compose exec backend python manage.py showmigrations inventory
docker compose exec db pg_dump -U postgres postgres > backup.sql

# Volume management
docker volume ls                              # List all volumes
docker volume inspect print-vault_media_volume # Inspect specific volume
docker system df -v                           # Show volume sizes

# Backup volumes
./scripts/backup-volumes.sh

# Restore volumes
./scripts/restore-volumes.sh

# Migrate from bind mounts
./scripts/migrate-to-native-volumes.sh
```

## Architecture

### Backend Structure

The backend is a single Django app called `inventory` that handles all business logic:

**Core Models (inventory/models.py):**
- **Inventory System:** `Brand`, `PartType`, `Location`, `InventoryItem`, `Vendor`
- **Filament Management:** `Material` (blueprint), `MaterialFeature`, `MaterialPhoto`, `FilamentSpool` (physical spools)
- **Printer Management:** `Printer`, `Mod`, `ModFile` (maintenance tracking)
- **Project Management:** `Project`, `ProjectInventory`, `ProjectPrinters`, `ProjectLink`, `ProjectFile`
- **Print Tracker:** `Tracker`, `TrackerFile` (import from GitHub/URLs/uploads)
- **Alerts:** `AlertDismissal` (dashboard notifications)

**Key Backend Patterns:**

1. **Services Layer:** Complex business logic lives in `inventory/services/`:
   - `github_service.py` - GitHub repository file fetching
   - `file_download_service.py` - URL-based file downloads with retry logic
   - `storage_manager.py` - Tracker file storage management (size limits, cleanup)

2. **ViewSets:** All CRUD operations use Django REST Framework `ModelViewSet` in `inventory/views.py`

3. **Custom API Views:** Special endpoints like `DashboardDataView`, `ExportDataView`, `ImportDataView` in views.py

4. **Settings:**
   - `backend/settings.py` - Development (SQLite)
   - `backend/production.py` - Production (PostgreSQL)
   - `TRACKER_STORAGE` dict in settings.py configures file size limits and download behavior

### Frontend Structure

Vue 3 SPA with the following organization:

**Views (frontend/src/views/):** Page-level components for routes
- Dashboard, inventory list/detail/edit, printer management, project management, tracker wizard, filament management

**Components (frontend/src/components/):** Reusable UI components
- `BaseModal.vue` - **ALWAYS use this for modals** (don't create custom modals)
- Form components, data tables, file configuration wizards

**Services (frontend/src/services/):** API communication
- Axios-based services for each backend endpoint

**Router (frontend/src/router/index.js):** Vue Router configuration

**Key Frontend Patterns:**

1. **Modal Pattern:** All modals MUST use `BaseModal.vue` component
2. **CSS Variables:** NEVER hardcode hex colors - use CSS variables from design system
3. **Mobile-First:** UI optimized for 30-second data entry on mobile devices
4. **PWA:** Service worker + manifest for "Add to Home Screen" functionality

### API Architecture

RESTful API served at `/api/` with:
- ViewSet-based CRUD endpoints (e.g., `/api/inventoryitems/`, `/api/printers/`)
- Custom endpoints for dashboard, data export/import, version checking
- DjangoFilterBackend for query filtering

**Important:** API contract changes require documentation updates per `chat_docs/instructions/API_DOCUMENTATION_WORKFLOW.md` before committing.

### File Storage

- **Docker volumes:** Three named volumes managed by Docker
  - `media_volume`: User uploads, tracker files, project files
  - `postgres_volume`: Database data
  - `static_volume`: Compiled frontend assets
- **Tracker files:** Organized in `media/trackers/{tracker_id}/{category}/` subdirectories
- **Project files:** In `media/project_files/{project_id}/`
- **Mod files:** In `media/mod_files/{mod_id}/`

Size limits enforced by `TRACKER_STORAGE` config (5GB per file, 100GB per tracker).

**Note:** Print Vault uses Docker native volumes instead of bind mounts for better portability and easier backup/restore operations.

### Filament Management System

Two-tier architecture:
1. **Materials (Blueprints):** Reusable material definitions with color, specs, temps, vendor info
2. **Filament Spools:** Physical spool instances linked to a material blueprint

Hybrid tracking: quantity-based for unopened spools, gram-based weight tracking for opened spools.

### Print Tracker System

Multi-source file import:
1. **GitHub Integration:** One-click import of entire repositories (uses `github_service.py`)
2. **Direct URLs:** Manual URL entry with download (uses `file_download_service.py`)
3. **File Uploads:** Computer file uploads

Files organized by category, with print queue tracking and "printed" status marking.

## Testing

**Backend:**
- Test framework: pytest with pytest-django
- Test location: `inventory/tests/`
- Organized by: models, views, serializers, services
- Factories: factory-boy + Faker for test data
- Coverage target: 95% (currently at 95%)
- Settings: `pytest.ini` configures test discovery and markers

**Frontend:**
- Test framework: Vitest + @vue/test-utils
- Test location: `frontend/src/tests/`
- DOM: happy-dom

**Test both light and dark modes** for UI changes before creating PRs.

## Environment Configuration

Development environment uses `.env` file with:
- `DJANGO_SECRET_KEY` - Required in production
- `DJANGO_DEBUG` - Set to False in production
- `POSTGRES_USER`, `POSTGRES_PASSWORD` - Database credentials
- `APP_HOST`, `APP_PORT` - Application access configuration
- `ALLOWED_HOSTS` - Comma-separated list of allowed domains

### New Environment Variables

- `POSTGRES_HOST` - Database host (default: 'db'). Use for external databases or custom service names.
- `POSTGRES_PORT` - Database port (default: 5432). Use for non-standard PostgreSQL ports.
- `BACKUP_DIR` - Backup directory for volume backup scripts (default: './backups').

## Important Constraints

From `chat_docs/instructions/` (Copilot rules):

1. **Modal UI:** Use `frontend/src/components/BaseModal.vue` - do not create custom modals
2. **Colors:** Use CSS variables - never hardcode hex colors
3. **Dev Servers:** Run in external PowerShell - Claude must not execute dev server commands
4. **Docker:** Use `docker compose` (space, not hyphen) for production
5. **API Changes:** Document contract changes before committing
6. **UI Testing:** Test both light and dark modes before PR
7. **Versioning:** Don't bump versions on every merge - follow VERSION_UPDATE_CHECKLIST.md

## Version Management

Application version tracked in `backend/version.py`. Check update endpoint at `/api/version/check-update/` compares against GitHub releases.

## Common Workflows

**Adding a new API endpoint:**
1. Create/modify model in `inventory/models.py`
2. Create serializer in `inventory/serializers.py`
3. Create ViewSet in `inventory/views.py`
4. Register in `backend/urls.py`
5. Run `python manage.py makemigrations` (user runs in terminal)
6. Document API contract changes

**Creating a new UI view:**
1. Create view component in `frontend/src/views/`
2. Add route in `frontend/src/router/index.js`
3. Use BaseModal for any modal dialogs
4. Use CSS variables for colors
5. Test in both light and dark modes

**Upgrading the application:**
1. User creates backup via Settings → Data Management
2. User runs database backup: `docker compose exec db pg_dump -U postgres postgres > backup.sql`
3. Pull latest changes: `git pull origin main`
4. Rebuild: `docker compose down && docker compose up -d --build --no-cache`
5. Migrations auto-run on container startup via entrypoint.sh
6. Verify: `docker compose exec backend python manage.py showmigrations inventory`
