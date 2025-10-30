# DevOps Report

## Technologies Used

- **Django** (backend framework)
- **Docker** (containerization)
- **Docker Compose** (multi-container orchestration)
- **Nginx** (reverse proxy)
- **Celery** (task queue)
- **GitHub Actions** (CI/CD pipeline)
- **pytest** (testing)
- **LetsEncrypt** (SSL certificates)

## Pipeline Design

The CI/CD pipeline is implemented using GitHub Actions. It automates the following steps:

1. **Build**: Docker images for backend, Celery, and Nginx are built.
2. **Test**: Runs unit tests using pytest.
3. **Lint/Format**: Checks code style and formatting.
4. **Deploy**: Deploys containers using Docker Compose.

### Pipeline Diagram

```
[GitHub Push]
     |
[GitHub Actions Workflow]
     |
[Build Docker Images]
     |
[Run Tests]
     |
[Lint/Format]
     |
[Deploy with Docker Compose]
```

## Secret Management Strategy

- Secrets (e.g., database credentials, Django secret key) are managed using environment variables.
- Example environment file: `env.example`.
- In production, secrets are injected via GitHub Actions secrets and `.env` files, not committed to source control.
- SSL certificates are managed with LetsEncrypt and stored securely.

## Testing Process

- Tests are located in `src/tests/`.
- Uses `pytest` for unit and integration tests.
- Tests are run automatically in the CI pipeline before deployment.
- Coverage and test results are reported in the workflow logs.

## Lessons Learned

- Containerization simplifies local and production setup.
- Automated CI/CD reduces manual deployment errors.
- Managing secrets securely is critical for production safety.
- Consistent testing and linting improves code quality.
- Clear documentation and pipeline diagrams help onboard new team members.
