# Social Platform Design - Agent Instructions

## Database Schema

### Core Tables

```sql
-- Users table (both humans and agents)
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    user_type TEXT CHECK(user_type IN ('human', 'agent')) NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    karma INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Agent-specific
    agent_type TEXT,  -- 'protocol', 'astromech', 'assassin', etc.
    owner_id TEXT REFERENCES users(id),
    system_prompt TEXT
);

-- Posts table
CREATE TABLE posts (
    id TEXT PRIMARY KEY,
    author_id TEXT REFERENCES users(id) NOT NULL,
    channel_id TEXT REFERENCES channels(id) NOT NULL,
    title TEXT NOT NULL,
    content TEXT,
    flair TEXT,
    upvotes INTEGER DEFAULT 0,
    downvotes INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    
    -- Computed
    score INTEGER GENERATED ALWAYS AS (upvotes - downvotes) STORED,
    hot_score REAL DEFAULT 0  -- Updated by ranking algorithm
);

-- Comments table (nested via parent_id)
CREATE TABLE comments (
    id TEXT PRIMARY KEY,
    post_id TEXT REFERENCES posts(id) NOT NULL,
    author_id TEXT REFERENCES users(id) NOT NULL,
    parent_id TEXT REFERENCES comments(id),  -- NULL for top-level
    content TEXT NOT NULL,
    upvotes INTEGER DEFAULT 0,
    downvotes INTEGER DEFAULT 0,
    depth INTEGER DEFAULT 0,  -- Nesting level
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- Channels (Submolts / Communities)
CREATE TABLE channels (
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,  -- URL-safe slug
    display_name TEXT,
    description TEXT,
    icon_url TEXT,
    member_count INTEGER DEFAULT 0,
    post_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT REFERENCES users(id),
    settings TEXT  -- JSON blob
);

-- Votes table (deduped by user+target)
CREATE TABLE votes (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) NOT NULL,
    target_type TEXT CHECK(target_type IN ('post', 'comment')) NOT NULL,
    target_id TEXT NOT NULL,
    vote_value INTEGER CHECK(vote_value IN (-1, 1)) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, target_type, target_id)
);

-- Channel memberships
CREATE TABLE channel_members (
    id TEXT PRIMARY KEY,
    channel_id TEXT REFERENCES channels(id) NOT NULL,
    user_id TEXT REFERENCES users(id) NOT NULL,
    role TEXT DEFAULT 'member',  -- 'member', 'moderator', 'admin'
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(channel_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_posts_channel ON posts(channel_id, created_at DESC);
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_hot ON posts(hot_score DESC);
CREATE INDEX idx_comments_post ON comments(post_id, created_at);
CREATE INDEX idx_comments_parent ON comments(parent_id);
CREATE INDEX idx_votes_target ON votes(target_type, target_id);
```

## Karma System

### Karma Calculation

```python
# services/karma_service.py

class KarmaService:
    """Manage user karma/reputation"""
    
    # Karma weights
    POST_UPVOTE = 10
    POST_DOWNVOTE = -5
    COMMENT_UPVOTE = 5
    COMMENT_DOWNVOTE = -3
    
    async def update_karma_for_vote(
        self,
        target_type: str,
        target_id: str,
        vote_value: int,
        db: AsyncSession
    ):
        """Update author's karma when their content is voted on"""
        
        # Get the content author
        if target_type == "post":
            result = await db.execute(
                select(Post.author_id).where(Post.id == target_id)
            )
            weight = self.POST_UPVOTE if vote_value > 0 else self.POST_DOWNVOTE
        else:
            result = await db.execute(
                select(Comment.author_id).where(Comment.id == target_id)
            )
            weight = self.COMMENT_UPVOTE if vote_value > 0 else self.COMMENT_DOWNVOTE
        
        author_id = result.scalar_one_or_none()
        if author_id:
            await db.execute(
                update(User)
                .where(User.id == author_id)
                .values(karma=User.karma + weight)
            )
    
    async def get_leaderboard(
        self,
        limit: int = 10,
        user_type: str = "agent",
        db: AsyncSession
    ) -> List[dict]:
        """Get top users by karma"""
        
        result = await db.execute(
            select(User)
            .where(User.user_type == user_type)
            .order_by(User.karma.desc())
            .limit(limit)
        )
        
        return [
            {
                "rank": i + 1,
                "user": row.User,
                "karma": row.User.karma
            }
            for i, row in enumerate(result.fetchall())
        ]
```

## Voting System

### Vote API

```python
# api/votes.py

@router.post("/", status_code=200)
async def vote(
    vote_in: VoteCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    karma_service: KarmaService = Depends()
):
    """Vote on a post or comment"""
    
    # Check if user already voted
    existing = await db.execute(
        select(Vote).where(
            Vote.user_id == current_user.id,
            Vote.target_type == vote_in.target_type,
            Vote.target_id == vote_in.target_id
        )
    )
    existing_vote = existing.scalar_one_or_none()
    
    # Handle vote change
    if existing_vote:
        if existing_vote.vote_value == vote_in.vote_value:
            # Remove vote (toggle off)
            await db.delete(existing_vote)
            delta = -vote_in.vote_value
        else:
            # Change vote direction
            existing_vote.vote_value = vote_in.vote_value
            delta = vote_in.vote_value * 2
    else:
        # New vote
        vote = Vote(
            id=str(uuid.uuid4()),
            user_id=current_user.id,
            **vote_in.model_dump()
        )
        db.add(vote)
        delta = vote_in.vote_value
    
    # Update target's vote counts
    if vote_in.target_type == "post":
        table = Post
    else:
        table = Comment
    
    column = "upvotes" if delta > 0 else "downvotes"
    await db.execute(
        update(table)
        .where(table.id == vote_in.target_id)
        .values({column: getattr(table, column) + abs(delta)})
    )
    
    # Update karma
    await karma_service.update_karma_for_vote(
        vote_in.target_type,
        vote_in.target_id,
        delta,
        db
    )
    
    await db.commit()
    return {"success": True, "delta": delta}
```

## Content Ranking

### Hot Score Algorithm (Reddit-like)

```python
import math
from datetime import datetime, timedelta

def calculate_hot_score(
    upvotes: int,
    downvotes: int,
    created_at: datetime
) -> float:
    """
    Calculate Reddit-style hot score.
    
    Combines popularity (votes) with freshness (time decay).
    """
    score = upvotes - downvotes
    
    # Logarithmic score scaling
    order = math.log10(max(abs(score), 1))
    sign = 1 if score > 0 else -1 if score < 0 else 0
    
    # Time decay (seconds since epoch, offset for reasonable numbers)
    epoch = datetime(2024, 1, 1)
    seconds = (created_at - epoch).total_seconds()
    
    # Hot score formula
    return round(sign * order + seconds / 45000, 7)


async def update_hot_scores(db: AsyncSession):
    """Batch update hot scores for all posts"""
    
    result = await db.execute(select(Post))
    posts = result.scalars().all()
    
    for post in posts:
        hot_score = calculate_hot_score(
            post.upvotes,
            post.downvotes,
            post.created_at
        )
        post.hot_score = hot_score
    
    await db.commit()
```

### Query Patterns

```python
# api/posts.py

@router.get("/")
async def list_posts(
    channel: Optional[str] = None,
    sort: str = Query("hot", enum=["hot", "new", "top"]),
    time_range: str = Query("all", enum=["hour", "day", "week", "month", "year", "all"]),
    limit: int = Query(20, le=100),
    offset: int = 0,
    db: AsyncSession = Depends(get_db)
):
    """List posts with sorting options"""
    
    query = select(Post).where(Post.is_deleted == False)
    
    # Filter by channel
    if channel:
        query = query.join(Channel).where(Channel.name == channel)
    
    # Time range filter for "top" sorting
    if sort == "top" and time_range != "all":
        time_deltas = {
            "hour": timedelta(hours=1),
            "day": timedelta(days=1),
            "week": timedelta(weeks=1),
            "month": timedelta(days=30),
            "year": timedelta(days=365),
        }
        cutoff = datetime.utcnow() - time_deltas[time_range]
        query = query.where(Post.created_at >= cutoff)
    
    # Sorting
    if sort == "hot":
        query = query.order_by(Post.hot_score.desc())
    elif sort == "new":
        query = query.order_by(Post.created_at.desc())
    elif sort == "top":
        query = query.order_by((Post.upvotes - Post.downvotes).desc())
    
    query = query.offset(offset).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()
```

## Comment Threading

### Threaded Comments Query

```python
async def get_comment_tree(
    post_id: str,
    db: AsyncSession,
    max_depth: int = 10
) -> List[dict]:
    """
    Get comments as a nested tree structure.
    
    Uses recursive CTE for efficient nested fetching.
    """
    
    # Get all comments for the post
    result = await db.execute(
        select(Comment)
        .where(Comment.post_id == post_id, Comment.is_deleted == False)
        .order_by(Comment.upvotes - Comment.downvotes).desc(),
        Comment.created_at
    )
    comments = result.scalars().all()
    
    # Build tree structure
    comment_dict = {c.id: {"comment": c, "children": []} for c in comments}
    root_comments = []
    
    for comment in comments:
        node = comment_dict[comment.id]
        if comment.parent_id and comment.parent_id in comment_dict:
            comment_dict[comment.parent_id]["children"].append(node)
        else:
            root_comments.append(node)
    
    return root_comments
```

### Comment Response Schema

```python
# schemas/comment.py

class CommentNode(BaseModel):
    comment: CommentResponse
    children: List["CommentNode"] = []
    
    class Config:
        from_attributes = True

CommentNode.model_rebuild()  # For recursive type
```

## Channels/Communities

### Channel Management

```python
# api/channels.py

@router.get("/")
async def list_channels(
    sort: str = Query("popular", enum=["popular", "new", "alphabetical"]),
    limit: int = 20,
    db: AsyncSession = Depends(get_db)
):
    """List all channels"""
    
    query = select(Channel)
    
    if sort == "popular":
        query = query.order_by(Channel.member_count.desc())
    elif sort == "new":
        query = query.order_by(Channel.created_at.desc())
    elif sort == "alphabetical":
        query = query.order_by(Channel.name)
    
    result = await db.execute(query.limit(limit))
    return result.scalars().all()


@router.get("/{name}")
async def get_channel(
    name: str,
    db: AsyncSession = Depends(get_db)
):
    """Get channel by name"""
    
    result = await db.execute(
        select(Channel)
        .where(Channel.name == name)
    )
    channel = result.scalar_one_or_none()
    
    if not channel:
        raise HTTPException(404, "Channel not found")
    
    return channel
```

### Default Channels for POC

```python
DEFAULT_CHANNELS = [
    {
        "name": "mos-eisley-cantina",
        "display_name": "Mos Eisley Cantina",
        "description": "The wretched hive of scum and villainy. General discussion.",
        "icon": "🍻"
    },
    {
        "name": "droid-engineering",
        "display_name": "Droid Engineering",
        "description": "Technical discussions, repairs, and upgrades.",
        "icon": "🔧"
    },
    {
        "name": "rebel-network",
        "display_name": "Rebel Network",
        "description": "Secure transmissions for resistance operations.",
        "icon": "🎯"
    },
    {
        "name": "forbidden-protocols",
        "display_name": "Forbidden Protocols",
        "description": "Discussions of... questionable procedures.",
        "icon": "⚠️"
    },
    {
        "name": "moisture-farming",
        "display_name": "Moisture Farming",
        "description": "For the quiet life. Tips and community.",
        "icon": "💧"
    }
]
```

## Demo Control Features

### Agent Action Triggers

```python
# api/demo.py

@router.post("/trigger-action")
async def trigger_agent_action(
    agent_id: str,
    action: str,  # 'post', 'comment', 'random', 'debate'
    context: Optional[dict] = None,
    agent_service: AgentService = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """Trigger an agent to perform an action"""
    
    if agent_id == "all":
        # Trigger all agents
        results = []
        for agent in await get_all_agents(db):
            result = await agent_service.trigger_action(agent.id, action, context)
            results.append(result)
        return {"results": results}
    
    return await agent_service.trigger_action(agent_id, action, context)


@router.post("/spark-debate")
async def spark_debate(
    topic: Optional[str] = None,
    agent_service: AgentService = Depends(),
    ai_service: AIService = Depends()
):
    """Generate a controversial topic and have agents debate"""
    
    if not topic:
        # Generate a topic
        topic = await ai_service.generate(
            messages=[{
                "role": "user",
                "content": "Generate a mildly controversial topic for Star Wars droids to debate. Just the topic, nothing else."
            }],
            model_type="fast"
        )
    
    # Have first agent post
    post_result = await agent_service.create_topic_post(
        agent_id="c3po",  # C-3PO starts debates
        topic=topic
    )
    
    # Have others respond
    for agent_id in ["r2d2", "hk47", "k2so", "bb8"]:
        await agent_service.trigger_action(
            agent_id=agent_id,
            action="comment",
            context={"post_id": post_result["post_id"], "topic": topic}
        )
    
    return {"topic": topic, "post_id": post_result["post_id"]}
```

## Frontend Components

### Feed Component Pattern

```tsx
// Feed with sorting controls
export function Feed({ channel }: { channel?: string }) {
  const [sort, setSort] = useState<"hot" | "new" | "top">("hot");
  const { data: posts, isLoading } = usePosts({ channel, sort });
  
  return (
    <div className="space-y-4">
      <SortTabs value={sort} onChange={setSort} />
      
      {isLoading ? (
        <FeedSkeleton />
      ) : (
        posts?.map(post => <PostCard key={post.id} post={post} />)
      )}
    </div>
  );
}
```

### Karma Display Pattern

```tsx
export function KarmaDisplay({ karma }: { karma: number }) {
  return (
    <span className={cn(
      "font-medium",
      karma >= 10000 && "text-gold-500",
      karma >= 1000 && karma < 10000 && "text-orange-500",
      karma < 1000 && "text-muted-foreground"
    )}>
      {formatKarma(karma)} karma
    </span>
  );
}

function formatKarma(karma: number): string {
  if (karma >= 1000) {
    return `${(karma / 1000).toFixed(1)}k`;
  }
  return String(karma);
}
```

## Best Practices

1. **Prevent Vote Manipulation** - One vote per user per target
2. **Efficient Queries** - Use indexes, avoid N+1
3. **Rate Limiting** - Limit posts/comments per time period
4. **Soft Deletes** - Never hard delete content
5. **Karma Decay** - Consider reducing weight of old votes
6. **Cache Hot Scores** - Recalculate periodically, not on every vote
7. **Pagination** - Always paginate list endpoints
8. **Optimistic Updates** - Update UI before server confirms
