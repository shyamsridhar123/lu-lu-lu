# FastAPI Backend Development - Agent Instructions

## Project Structure

Use this standard project structure for FastAPI applications:

```text
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app entry point
│   ├── config.py            # Configuration with pydantic-settings
│   ├── database.py          # Database connection and session
│   │
│   ├── api/                 # API routers
│   │   ├── __init__.py
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── posts.py
│   │   │   ├── comments.py
│   │   │   ├── users.py
│   │   │   └── agents.py
│   │   └── deps.py          # Shared dependencies
│   │
│   ├── models/              # SQLAlchemy/SQLModel models
│   │   ├── __init__.py
│   │   ├── user.py
│   │   ├── post.py
│   │   └── base.py
│   │
│   ├── schemas/             # Pydantic schemas
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── post.py
│   │
│   ├── services/            # Business logic
│   │   ├── __init__.py
│   │   ├── ai_service.py
│   │   └── agent_service.py
│   │
│   ├── core/                # Core utilities
│   │   ├── __init__.py
│   │   ├── security.py
│   │   └── exceptions.py
│   │
│   └── utils/               # Helpers
│       └── __init__.py
│
├── tests/
├── alembic/                 # Database migrations
├── requirements.txt
├── pyproject.toml
└── .env.example
```

## Main Application Pattern

```python
# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.database import init_db
from app.api.v1 import posts, comments, users, agents

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    yield
    # Shutdown

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(posts.router, prefix="/api/posts", tags=["Posts"])
app.include_router(comments.router, prefix="/api/comments", tags=["Comments"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(agents.router, prefix="/api/agents", tags=["Agents"])

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
```

## Configuration Pattern

```python
# app/config.py
from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    # Project
    PROJECT_NAME: str = "Tatooine Holonet API"
    PROJECT_DESCRIPTION: str = "Social network for AI agents"
    
    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./app.db"
    
    # Azure OpenAI
    AZURE_OPENAI_ENDPOINT: str
    AZURE_OPENAI_API_KEY: str
    AZURE_OPENAI_API_VERSION: str = "2024-12-01-preview"
    AZURE_DEPLOYMENT_REASONING: str = "gpt-5.1"
    AZURE_DEPLOYMENT_CHAT: str = "gpt-5-chat"
    AZURE_DEPLOYMENT_FAST: str = "gpt-5-nano"
    
    # Security
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # CORS
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000"]
    
    class Config:
        env_file = ".env"

settings = Settings()
```

## Database Setup (Async SQLAlchemy)

```python
# app/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=True,  # SQL logging (disable in prod)
)

AsyncSessionLocal = sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

Base = declarative_base()

async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## Model Pattern (SQLAlchemy)

```python
# app/models/post.py
from sqlalchemy import Column, String, Integer, Text, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.database import Base

class Post(Base):
    __tablename__ = "posts"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(300), nullable=False)
    content = Column(Text)
    author_id = Column(String, ForeignKey("users.id"), nullable=False)
    channel_id = Column(String, ForeignKey("channels.id"), nullable=False)
    
    upvotes = Column(Integer, default=0)
    downvotes = Column(Integer, default=0)
    comment_count = Column(Integer, default=0)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_deleted = Column(Boolean, default=False)
    
    # Relationships
    author = relationship("User", back_populates="posts")
    channel = relationship("Channel", back_populates="posts")
    comments = relationship("Comment", back_populates="post")
```

## Schema Pattern (Pydantic)

```python
# app/schemas/post.py
from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class PostBase(BaseModel):
    title: str = Field(..., max_length=300)
    content: str
    channel_id: str
    flair: Optional[str] = None

class PostCreate(PostBase):
    pass

class PostUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=300)
    content: Optional[str] = None

class PostResponse(PostBase):
    id: str
    author_id: str
    upvotes: int
    downvotes: int
    comment_count: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
```

## Router Pattern

```python
# app/api/v1/posts.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional

from app.database import get_db
from app.models.post import Post
from app.schemas.post import PostCreate, PostResponse, PostUpdate

router = APIRouter()

@router.get("/", response_model=List[PostResponse])
async def list_posts(
    channel: Optional[str] = None,
    limit: int = Query(20, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db)
):
    query = select(Post).where(Post.is_deleted == False)
    
    if channel:
        query = query.where(Post.channel_id == channel)
    
    query = query.offset(offset).limit(limit).order_by(Post.created_at.desc())
    
    result = await db.execute(query)
    return result.scalars().all()

@router.get("/{post_id}", response_model=PostResponse)
async def get_post(post_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Post).where(Post.id == post_id, Post.is_deleted == False)
    )
    post = result.scalar_one_or_none()
    
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    return post

@router.post("/", response_model=PostResponse, status_code=201)
async def create_post(
    post_in: PostCreate,
    author_id: str,  # Would come from auth in real app
    db: AsyncSession = Depends(get_db)
):
    post = Post(**post_in.model_dump(), author_id=author_id)
    db.add(post)
    await db.commit()
    await db.refresh(post)
    return post

@router.patch("/{post_id}", response_model=PostResponse)
async def update_post(
    post_id: str,
    post_in: PostUpdate,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Post).where(Post.id == post_id))
    post = result.scalar_one_or_none()
    
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    for field, value in post_in.model_dump(exclude_unset=True).items():
        setattr(post, field, value)
    
    await db.commit()
    await db.refresh(post)
    return post

@router.delete("/{post_id}", status_code=204)
async def delete_post(post_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Post).where(Post.id == post_id))
    post = result.scalar_one_or_none()
    
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    post.is_deleted = True
    await db.commit()
```

## Dependency Injection Pattern

```python
# app/api/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.config import settings
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = await db.get(User, user_id)
    if user is None:
        raise credentials_exception
    
    return user

async def get_current_agent(
    user: User = Depends(get_current_user)
) -> User:
    if user.user_type != "agent":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Agent-only endpoint"
        )
    return user
```

## Error Handling Pattern

```python
# app/core/exceptions.py
from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse

class AppException(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail

class NotFoundError(AppException):
    def __init__(self, resource: str):
        super().__init__(404, f"{resource} not found")

class ValidationError(AppException):
    def __init__(self, detail: str):
        super().__init__(422, detail)

async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )

# Register in main.py:
# app.add_exception_handler(AppException, app_exception_handler)
```

## Background Tasks Pattern

```python
# For simple tasks
from fastapi import BackgroundTasks

@router.post("/posts/{post_id}/notify")
async def notify_subscribers(
    post_id: str,
    background_tasks: BackgroundTasks
):
    background_tasks.add_task(send_notifications, post_id)
    return {"message": "Notifications queued"}

# For complex tasks, use Celery with Redis
```

## Testing Pattern

```python
# tests/test_posts.py
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def async_client():
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client

@pytest.mark.asyncio
async def test_create_post(async_client):
    response = await async_client.post(
        "/api/posts/",
        json={
            "title": "Test Post",
            "content": "Test content",
            "channel_id": "test-channel"
        }
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Test Post"
```

## Performance Best Practices

1. **Use async everywhere** - All DB operations, HTTP calls should be async
2. **Connection pooling** - Configure SQLAlchemy pool size appropriately
3. **Pagination** - Always paginate list endpoints
4. **Caching** - Use Redis for frequently accessed data
5. **Lazy loading** - Avoid N+1 queries with `selectinload`
6. **Response compression** - Enable gzip middleware

## Security Best Practices

1. **CORS configuration** - Whitelist specific origins in production
2. **Rate limiting** - Implement per-user rate limits
3. **Input validation** - Pydantic handles this, but validate edge cases
4. **SQL injection** - Use parameterized queries (ORM handles this)
5. **Secrets management** - Never commit .env files
6. **HTTPS only** - Enforce in production
