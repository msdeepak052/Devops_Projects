Here’s an end-to-end template setup for the **Expense Tracker App**, covering **every essential file**, along with a step-by-step guide to build and deploy it on **AWS EKS** with **RDS**, **Jenkins CI**, and **Argo CD**.

---

## 📁 Project Structure

```
expense-tracker/
├── frontend/
│   ├── app.py
│   ├── templates/
│   │   └── index.html
│   ├── requirements.txt
│   └── Dockerfile
backend/
├── Dockerfile
├── requirements.txt
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── models.py
│   ├── schemas.py
│   ├── crud.py
│   ├── database.py
│   └── tests/
│       └── test_api.py
├── jenkins/
│   ├── frontend/Jenkinsfile
│   └── backend/Jenkinsfile
├── k8s/
│   ├── frontend-deployment.yaml
│   ├── backend-deployment.yaml
│   ├── service-frontend.yaml
│   ├── service-backend.yaml
│   └── configmap-secret.yaml
└── argo-cd/
    └── application.yaml
```

---

## 🔧 1. Frontend - Flask

### `frontend/app.py`

```python
from flask import Flask, render_template, request
import requests
app = Flask(__name__)

API_URL = "http://backend:8000"

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        category = request.form["category"]
        amount = float(request.form["amount"])
        requests.post(f"{API_URL}/expenses/", json={"category": category, "amount": amount})
    resp = requests.get(f"{API_URL}/expenses/")
    expenses = resp.json()
    total = sum(e["amount"] for e in expenses)
    return render_template("index.html", expenses=expenses, total=total)
```

### `frontend/templates/index.html`

```html
<!DOCTYPE html>
<html>
<head><title>Expense Tracker</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.0.0/dist/css/bootstrap.min.css" rel="stylesheet"></head>
<body class="container py-5">
  <h1>Expense Tracker</h1>
  <form method="post" class="row g-2">
    <div class="col-auto"><input name="category" placeholder="Category" class="form-control" required></div>
    <div class="col-auto"><input name="amount" type="number" step="0.01" placeholder="Amount" class="form-control" required></div>
    <div class="col-auto"><button class="btn btn-primary">Add</button></div>
  </form>
  <h2 class="mt-4">Total: ${{ total }}</h2>
  <ul class="list-group mt-3">{% for e in expenses %}
    <li class="list-group-item">{{ e.category }} – ${{ e.amount }}</li>{% endfor %}
  </ul>
</body>
</html>
```

### `frontend/requirements.txt`

```
Flask==2.2.2
requests==2.28.2
```

### `frontend/Dockerfile`

```dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py", "--host=0.0.0.0", "--port=5000"]
```

---

## 🧩 2. Backend - FastAPI

### `backend/app/database.py`

```python
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
```

### `backend/app/models.py`

```python
from sqlalchemy import Column, Integer, String, Float, DateTime, func
from app.database import Base

class Expense(Base):
    __tablename__ = "expenses"
    id = Column(Integer, primary_key=True, index=True)
    category = Column(String, index=True)
    amount = Column(Float)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
```

### `backend/app/schemas.py`

```python
from pydantic import BaseModel

class ExpenseCreate(BaseModel):
    category: str
    amount: float

class Expense(BaseModel):
    id: int
    category: str
    amount: float
    created_at: str

    class Config:
        orm_mode = True
```

### `backend/app/crud.py`

```python
from sqlalchemy.orm import Session
from app import models, schemas

def get_expenses(db: Session):
    return db.query(models.Expense).all()

def create_expense(db: Session, expense: schemas.ExpenseCreate):
    db_exp = models.Expense(**expense.dict())
    db.add(db_exp)
    db.commit()
    db.refresh(db_exp)
    return db_exp
```

### `backend/app/main.py`

```python
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from app import models, schemas, crud, database
import os

models.Base.metadata.create_all(bind=database.engine)
app = FastAPI()

def get_db():
    db = database.SessionLocal()
    try: yield db
    finally: db.close()

@app.post("/expenses/", response_model=schemas.Expense)
def add_expense(expense: schemas.ExpenseCreate, db: Session = Depends(get_db)):
    return crud.create_expense(db, expense)

@app.get("/expenses/", response_model=list[schemas.Expense])
def list_expenses(db: Session = Depends(get_db)):
    return crud.get_expenses(db)
```

### `backend/requirements.txt`

```
fastapi==0.95.2
uvicorn==0.22.0
sqlalchemy==2.0.19
psycopg2-binary==2.9.7
```

### `backend/app/tests/test_api.py`

```python
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_add_and_list():
    resp = client.post("/expenses/", json={"category": "Food", "amount": 10.0})
    assert resp.status_code == 200
    data = resp.json()
    assert data["category"] == "Food"
    resp2 = client.get("/expenses/")
    assert resp2.status_code == 200
    assert any(e["id"] == data["id"] for e in resp2.json())
```

### `backend/Dockerfile`

```dockerfile
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```
### `backend/init.py`

```empty file  ```

---

## 🛠️ 3. CI – Jenkins Pipelines

### `jenkins/frontend/Jenkinsfile`

```groovy
pipeline {
  agent any
  environment {
    ECR_REPO = '123456789012.dkr.ecr.eu-west-1.amazonaws.com/expense-frontend'
  }
  stages {
    stage('Install & Test') {
      steps {
        dir('frontend') {
          sh 'pip install -r requirements.txt'
        }
      }
    }
    stage('Docker Build & Push') {
      steps {
        script { sh '''
          aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR_REPO
          cd frontend
          docker build -t $ECR_REPO:latest .
          docker push $ECR_REPO:latest
        ''' }
      }
    }
  }
}
```

### `jenkins/backend/Jenkinsfile`

```groovy
pipeline {
  agent any
  environment {
    ECR_REPO = '123456789012.dkr.ecr.eu-west-1.amazonaws.com/expense-backend'
  }
  stages {
    stage('Lint & Test') {
      steps {
        dir('backend') {
          sh 'pip install -r requirements.txt'
          sh 'flake8 . || true'
          sh 'pytest -q'
        }
      }
    }
    stage('Docker Build & Push') {
      steps {
        script { sh '''
          aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR_REPO
          cd backend
          docker build -t $ECR_REPO:latest .
          docker push $ECR_REPO:latest
        ''' }
      }
    }
  }
}
```

---

## ☸️ 4. Kubernetes & Argo CD

### `k8s/configmap-secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  DATABASE_URL: {{ .Values.dbUrlEncoded }}

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: env-config
data:
  CUSTOM_ENV: "prod"
```

### `k8s/frontend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: frontend }
spec:
  replicas: 2
  selector: { matchLabels: { app: frontend } }
  template:
    metadata: { labels: { app: frontend } }
    spec:
      containers:
      - name: frontend
        image: 123456789012.dkr.ecr.eu-west-1.amazonaws.com/expense-frontend:latest
        ports: [{ containerPort: 5000 }]
        envFrom:
          - secretRef: { name: db-secret }
```

### `k8s/service-frontend.yaml`

```yaml
apiVersion: v1
kind: Service
metadata: { name: frontend }
spec:
  type: LoadBalancer
  selector: { app: frontend }
  ports: [{ port: 80, targetPort: 5000 }]
```

### `k8s/backend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: backend }
spec:
  replicas: 2
  selector: { matchLabels: { app: backend } }
  template:
    metadata: { labels: { app: backend } }
    spec:
      containers:
      - name: backend
        image: 123456789012.dkr.ecr.eu-west-1.amazonaws.com/expense-backend:latest
        ports: [{ containerPort: 8000 }]
        envFrom:
          - secretRef: { name: db-secret }
```

### `k8s/service-backend.yaml`

```yaml
apiVersion: v1
kind: Service
metadata: { name: backend }
spec:
  selector: { app: backend }
  ports: [{ port: 80, targetPort: 8000 }]
```

### `argo-cd/application.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: expense-tracker
spec:
  project: default
  source:
    repoURL: 'git@github.com:your_org/expense-tracker.git'
    path: 'k8s'
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## ✅ Step-by-Step Implementation

1. **AWS RDS (PostgreSQL)**

   * Launch RDS instance.
   * Set `DATABASE_URL=postgresql://user:pass@<endpoint>:5432/expenses_db`.

2. **Build & Push Images**

   * Create ECR repos for both frontend and backend.
   * Trigger Jenkins jobs to build and push Docker images.

3. **Helm/K8s Setup**

   * Ensure EKS cluster is ready and has permissions (IAM, RBAC).
   * Place DB URL (base64-encoded) into `db-secret`.

4. **Argo CD Deployment**

   * Ensure Argo CD is installed on the EKS cluster.
   * Apply `application.yaml` to register the deployment.
   * Argo CD will sync the deployments and services automatically.

5. **Access the App**

   * Get the external LoadBalancer URL for the `frontend` service.
   * Visit via browser – expenses should appear and persist in RDS.

---

### Docker testing

#### Build the backend image (from project root):

```bash
docker build -t expense-backend -f backend/Dockerfile ./backend
```

#### Run the services:


#### Create network
```bash 
docker network create expense-tracker-net

```

##### Start PostgreSQL
```bash
 docker run -d \
  --name expense-db \
  --network expense-tracker-net \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=pass \
  -e POSTGRES_DB=expenses_db \
  -p 5432:5432 \
  postgres:13-alpine

```

# Wait for DB to initialize
```sleep 15 ```

#### Start backend
```bash
  docker run -d \
  --name backend \
  --network expense-tracker-net \
  -e DATABASE_URL="postgresql://user:pass@expense-db:5432/expenses_db" \
  -p 8000:8000 \
  expense-backend
```
#### Verify it's working:

```bash
curl -X POST -H "Content-Type: application/json" -d '{"category":"Test","amount":10.5}' http://localhost:8000/expenses/
curl http://localhost:8000/expenses/
```

# End-to-End Connectivity Guide for Expense Tracker App on EKS

Let me explain how the frontend, backend, and database connect in this architecture when deployed on EKS.

## 1. Database Connection (Backend to RDS)

**Where it's configured:**
- `backend/app/database.py` contains the database connection logic
- The connection string comes from the environment variable `DATABASE_URL`

**Key points:**
```python
DATABASE_URL = os.getenv("DATABASE_URL")  # Format: postgresql://user:password@host:port/dbname
engine = create_engine(DATABASE_URL)
```

**When deploying to EKS:**
1. You'll need to create an RDS PostgreSQL instance
2. Store the connection details in a Kubernetes Secret:
   ```yaml
   # k8s/configmap-secret.yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: backend-secrets
   type: Opaque
   data:
     DATABASE_URL: <base64-encoded-connection-string>
   ```
3. Mount this secret to your backend deployment

## 2. Frontend to Backend Connection

**Where it's configured:**
- `frontend/app.py` has the backend API URL configuration:
  ```python
  API_URL = "http://backend:8000"  # 'backend' is the Kubernetes service name
  ```

**Key points:**
1. The frontend connects to backend using the Kubernetes service name (`backend`)
2. Port 8000 is the default FastAPI port (configured in backend's Dockerfile)

**When deploying to EKS:**
1. You'll need:
   - A backend Service (ClusterIP) exposing port 8000
   - A frontend Service (LoadBalancer) exposing port 5000

Example service definitions:
```yaml
# k8s/service-backend.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 8000

# k8s/service-frontend.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
```

## 3. Network Flow in EKS

```
Internet User → AWS ALB (via frontend Service) → Frontend Pod (port 5000)
Frontend Pod → Backend Service (DNS name "backend") → Backend Pod (port 8000)
Backend Pod → RDS Endpoint (from DATABASE_URL secret)
```

## 4. Port Configuration Summary

| Component | Container Port | Service Port | Exposed As |
|-----------|----------------|--------------|------------|
| Frontend  | 5000           | 80 (Service) | ALB (port 80) |
| Backend   | 8000           | 8000         | Cluster-internal (backend:8000) |

## 5. Required Kubernetes Manifests

You'll need these essential manifests:

1. **Deployments** (frontend-deployment.yaml, backend-deployment.yaml)
   - Ensure backend has the secret mounted
   - Both should have proper liveness/readiness probes

2. **Services** (service-frontend.yaml, service-backend.yaml)
   - Frontend as LoadBalancer
   - Backend as ClusterIP

3. **ConfigMap/Secret** (configmap-secret.yaml)
   - Contains DATABASE_URL and any other configs

4. **Ingress** (optional, if using ALB)
   - To route traffic to frontend service

## 6. DNS Resolution in EKS

- Frontend accesses backend via Kubernetes DNS:
  - Service name `backend` resolves to ClusterIP
  - Port 8000 is the backend service port
- Backend accesses RDS via the full RDS endpoint URL from the secret

Would you like me to provide the complete deployment YAML files or explain any specific part in more detail?
