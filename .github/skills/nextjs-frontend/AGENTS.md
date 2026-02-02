# Next.js Frontend Development - Agent Instructions

## Project Structure

Use this standard project structure for Next.js App Router applications:

```text
frontend/
├── app/
│   ├── layout.tsx           # Root layout
│   ├── page.tsx             # Home page
│   ├── globals.css          # Global styles
│   ├── loading.tsx          # Global loading state
│   ├── error.tsx            # Global error boundary
│   │
│   ├── (routes)/            # Route groups
│   │   ├── feed/
│   │   │   ├── page.tsx
│   │   │   └── loading.tsx
│   │   ├── post/
│   │   │   └── [id]/
│   │   │       └── page.tsx
│   │   ├── channel/
│   │   │   └── [name]/
│   │   │       └── page.tsx
│   │   └── catalog/
│   │       └── page.tsx
│   │
│   └── api/                 # API routes (if needed)
│       └── route.ts
│
├── components/
│   ├── ui/                  # shadcn/ui components
│   ├── layout/
│   │   ├── Header.tsx
│   │   ├── Sidebar.tsx
│   │   └── Footer.tsx
│   ├── feed/
│   │   ├── PostCard.tsx
│   │   ├── PostList.tsx
│   │   └── VoteButtons.tsx
│   ├── comments/
│   │   ├── CommentThread.tsx
│   │   └── CommentForm.tsx
│   └── demo/
│       └── DemoControlPanel.tsx
│
├── lib/
│   ├── api.ts               # API client
│   ├── utils.ts             # Utility functions
│   └── constants.ts         # App constants
│
├── hooks/
│   ├── usePosts.ts          # Post data hooks
│   ├── useAgents.ts         # Agent data hooks
│   └── useVote.ts           # Voting hooks
│
├── types/
│   ├── post.ts
│   ├── user.ts
│   └── agent.ts
│
├── public/
│   └── avatars/
│
├── tailwind.config.ts
├── next.config.js
└── package.json
```

## Root Layout Pattern

```tsx
// app/layout.tsx
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { QueryProvider } from "@/components/providers/QueryProvider";
import { Header } from "@/components/layout/Header";
import { Sidebar } from "@/components/layout/Sidebar";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Tatooine Holonet",
  description: "A social network for droids and AI agents",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <QueryProvider>
          <div className="min-h-screen bg-background">
            <Header />
            <div className="flex container mx-auto px-4">
              <main className="flex-1 py-6">{children}</main>
              <Sidebar className="hidden lg:block w-80 ml-6" />
            </div>
          </div>
        </QueryProvider>
      </body>
    </html>
  );
}
```

## API Client Pattern

```typescript
// lib/api.ts
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

class ApiClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setToken(token: string) {
    this.token = token;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const headers: HeadersInit = {
      "Content-Type": "application/json",
      ...options.headers,
    };

    if (this.token) {
      headers["Authorization"] = `Bearer ${this.token}`;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.detail || `HTTP ${response.status}`);
    }

    return response.json();
  }

  // Posts
  async getPosts(params?: { channel?: string; limit?: number; offset?: number }) {
    const searchParams = new URLSearchParams();
    if (params?.channel) searchParams.set("channel", params.channel);
    if (params?.limit) searchParams.set("limit", String(params.limit));
    if (params?.offset) searchParams.set("offset", String(params.offset));
    
    return this.request<Post[]>(`/api/posts?${searchParams}`);
  }

  async getPost(id: string) {
    return this.request<Post>(`/api/posts/${id}`);
  }

  async createPost(data: CreatePostInput) {
    return this.request<Post>("/api/posts", {
      method: "POST",
      body: JSON.stringify(data),
    });
  }

  // Comments
  async getComments(postId: string) {
    return this.request<Comment[]>(`/api/posts/${postId}/comments`);
  }

  async createComment(data: CreateCommentInput) {
    return this.request<Comment>("/api/comments", {
      method: "POST",
      body: JSON.stringify(data),
    });
  }

  // Votes
  async vote(targetType: "post" | "comment", targetId: string, value: 1 | -1) {
    return this.request<Vote>("/api/votes", {
      method: "POST",
      body: JSON.stringify({ target_type: targetType, target_id: targetId, vote_value: value }),
    });
  }

  // Agents
  async getAgents() {
    return this.request<Agent[]>("/api/agents");
  }

  async triggerAgentAction(agentId: string, action: string) {
    return this.request<AgentActionResult>(`/api/demo/trigger-action`, {
      method: "POST",
      body: JSON.stringify({ agent_id: agentId, action }),
    });
  }
}

export const api = new ApiClient(API_BASE_URL);
```

## React Query Hooks Pattern

```typescript
// hooks/usePosts.ts
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Post, CreatePostInput } from "@/types/post";

export function usePosts(channel?: string) {
  return useQuery({
    queryKey: ["posts", { channel }],
    queryFn: () => api.getPosts({ channel }),
    refetchInterval: 3000, // Poll for new posts every 3s
  });
}

export function usePost(id: string) {
  return useQuery({
    queryKey: ["post", id],
    queryFn: () => api.getPost(id),
    enabled: !!id,
  });
}

export function useCreatePost() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (data: CreatePostInput) => api.createPost(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["posts"] });
    },
  });
}
```

```typescript
// hooks/useVote.ts
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";

export function useVote() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ 
      targetType, 
      targetId, 
      value 
    }: { 
      targetType: "post" | "comment"; 
      targetId: string; 
      value: 1 | -1; 
    }) => api.vote(targetType, targetId, value),
    onSuccess: (_, variables) => {
      // Optimistically update the UI
      queryClient.invalidateQueries({ queryKey: ["posts"] });
      if (variables.targetType === "post") {
        queryClient.invalidateQueries({ queryKey: ["post", variables.targetId] });
      }
    },
  });
}
```

## Component Patterns

### Post Card Component

```tsx
// components/feed/PostCard.tsx
"use client";

import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { VoteButtons } from "./VoteButtons";
import { AgentBadge } from "@/components/ui/AgentBadge";
import type { Post } from "@/types/post";

interface PostCardProps {
  post: Post;
}

export function PostCard({ post }: PostCardProps) {
  return (
    <div className="bg-card rounded-lg border p-4 hover:border-primary/50 transition">
      <div className="flex gap-4">
        {/* Votes */}
        <VoteButtons
          targetType="post"
          targetId={post.id}
          upvotes={post.upvotes}
          downvotes={post.downvotes}
        />

        {/* Content */}
        <div className="flex-1 min-w-0">
          {/* Meta */}
          <div className="flex items-center gap-2 text-sm text-muted-foreground mb-2">
            <Link href={`/channel/${post.channel.name}`} className="hover:underline">
              t/{post.channel.name}
            </Link>
            <span>•</span>
            <Link href={`/u/${post.author.username}`} className="hover:underline">
              {post.author.display_name}
            </Link>
            {post.author.user_type === "agent" && <AgentBadge />}
            <span>•</span>
            <span>{formatDistanceToNow(new Date(post.created_at))} ago</span>
          </div>

          {/* Flair */}
          {post.flair && (
            <span className="inline-block bg-primary/10 text-primary text-xs px-2 py-0.5 rounded mb-2">
              {post.flair}
            </span>
          )}

          {/* Title */}
          <Link href={`/post/${post.id}`}>
            <h2 className="text-lg font-semibold hover:underline mb-2">
              {post.title}
            </h2>
          </Link>

          {/* Preview */}
          {post.content && (
            <p className="text-muted-foreground line-clamp-3 mb-4">
              {post.content}
            </p>
          )}

          {/* Actions */}
          <div className="flex items-center gap-4 text-sm text-muted-foreground">
            <Link href={`/post/${post.id}`} className="hover:text-foreground">
              💬 {post.comment_count} comments
            </Link>
            <button className="hover:text-foreground">📤 Share</button>
            <button className="hover:text-foreground">📁 Save</button>
          </div>
        </div>
      </div>
    </div>
  );
}
```

### Vote Buttons Component

```tsx
// components/feed/VoteButtons.tsx
"use client";

import { useState } from "react";
import { ChevronUp, ChevronDown } from "lucide-react";
import { useVote } from "@/hooks/useVote";
import { cn } from "@/lib/utils";

interface VoteButtonsProps {
  targetType: "post" | "comment";
  targetId: string;
  upvotes: number;
  downvotes: number;
  className?: string;
}

export function VoteButtons({
  targetType,
  targetId,
  upvotes,
  downvotes,
  className,
}: VoteButtonsProps) {
  const [currentVote, setCurrentVote] = useState<1 | -1 | null>(null);
  const { mutate: vote } = useVote();

  const score = upvotes - downvotes;

  const handleVote = (value: 1 | -1) => {
    const newValue = currentVote === value ? null : value;
    setCurrentVote(newValue as 1 | -1 | null);
    
    if (newValue) {
      vote({ targetType, targetId, value: newValue });
    }
  };

  return (
    <div className={cn("flex flex-col items-center gap-1", className)}>
      <button
        onClick={() => handleVote(1)}
        className={cn(
          "p-1 rounded hover:bg-accent",
          currentVote === 1 && "text-orange-500"
        )}
      >
        <ChevronUp className="w-6 h-6" />
      </button>
      
      <span className={cn(
        "font-medium",
        currentVote === 1 && "text-orange-500",
        currentVote === -1 && "text-blue-500"
      )}>
        {score}
      </span>
      
      <button
        onClick={() => handleVote(-1)}
        className={cn(
          "p-1 rounded hover:bg-accent",
          currentVote === -1 && "text-blue-500"
        )}
      >
        <ChevronDown className="w-6 h-6" />
      </button>
    </div>
  );
}
```

### Demo Control Panel

```tsx
// components/demo/DemoControlPanel.tsx
"use client";

import { useState } from "react";
import { useAgentAction } from "@/hooks/useAgentAction";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import type { Agent } from "@/types/agent";

const DEMO_AGENTS: Agent[] = [
  { id: "c3po", name: "C-3PO", avatar: "🤖" },
  { id: "r2d2", name: "R2-D2", avatar: "🔧" },
  { id: "hk47", name: "HK-47", avatar: "💀" },
  { id: "k2so", name: "K-2SO", avatar: "🛡️" },
  { id: "bb8", name: "BB-8", avatar: "⚪" },
];

export function DemoControlPanel() {
  const [isOpen, setIsOpen] = useState(true);
  const { mutate: triggerAction, isPending } = useAgentAction();

  return (
    <Card className="p-4 mb-6 border-primary/50">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-semibold flex items-center gap-2">
          🤖 DEMO CONTROL PANEL
          <span className="text-xs bg-primary text-primary-foreground px-2 py-0.5 rounded">
            POC
          </span>
        </h3>
        <Button variant="ghost" size="sm" onClick={() => setIsOpen(!isOpen)}>
          {isOpen ? "Hide" : "Show"}
        </Button>
      </div>

      {isOpen && (
        <>
          {/* Agent buttons */}
          <div className="flex flex-wrap gap-3 mb-4">
            {DEMO_AGENTS.map((agent) => (
              <div key={agent.id} className="flex flex-col items-center gap-2">
                <span className="text-2xl">{agent.avatar}</span>
                <span className="text-xs font-medium">{agent.name}</span>
                <div className="flex gap-1">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => triggerAction({ agentId: agent.id, action: "post" })}
                    disabled={isPending}
                  >
                    📝 Post
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => triggerAction({ agentId: agent.id, action: "comment" })}
                    disabled={isPending}
                  >
                    💬 Reply
                  </Button>
                </div>
              </div>
            ))}
          </div>

          {/* Quick actions */}
          <div className="flex gap-2">
            <Button
              onClick={() => triggerAction({ agentId: "all", action: "random" })}
              disabled={isPending}
            >
              ⚡ All Agents: Random Action
            </Button>
            <Button
              variant="secondary"
              onClick={() => triggerAction({ agentId: "all", action: "debate" })}
              disabled={isPending}
            >
              💬 Spark Debate
            </Button>
          </div>
        </>
      )}
    </Card>
  );
}
```

## Query Provider Setup

```tsx
// components/providers/QueryProvider.tsx
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { useState } from "react";

export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 5 * 1000, // 5 seconds
            refetchOnWindowFocus: true,
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

## Server Component Data Fetching

```tsx
// app/post/[id]/page.tsx
import { api } from "@/lib/api";
import { PostDetail } from "@/components/post/PostDetail";
import { CommentThread } from "@/components/comments/CommentThread";
import { notFound } from "next/navigation";

interface PostPageProps {
  params: { id: string };
}

async function getPost(id: string) {
  try {
    return await api.getPost(id);
  } catch {
    return null;
  }
}

export default async function PostPage({ params }: PostPageProps) {
  const post = await getPost(params.id);

  if (!post) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <PostDetail post={post} />
      <CommentThread postId={post.id} />
    </div>
  );
}

export async function generateMetadata({ params }: PostPageProps) {
  const post = await getPost(params.id);
  
  return {
    title: post ? `${post.title} | Tatooine Holonet` : "Post Not Found",
    description: post?.content?.slice(0, 160),
  };
}
```

## Loading States

```tsx
// app/loading.tsx
import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return (
    <div className="space-y-4">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="bg-card rounded-lg border p-4">
          <div className="flex gap-4">
            <Skeleton className="w-10 h-24" />
            <div className="flex-1 space-y-3">
              <Skeleton className="h-4 w-1/3" />
              <Skeleton className="h-6 w-3/4" />
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-2/3" />
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
```

## Tailwind Configuration

```typescript
// tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: ["class"],
  content: [
    "./pages/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./app/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: "hsl(var(--card))",
        "card-foreground": "hsl(var(--card-foreground))",
        primary: "hsl(var(--primary))",
        "primary-foreground": "hsl(var(--primary-foreground))",
        muted: "hsl(var(--muted))",
        "muted-foreground": "hsl(var(--muted-foreground))",
        accent: "hsl(var(--accent))",
        border: "hsl(var(--border))",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
```

## Best Practices

1. **Use Server Components by default** - Only add "use client" when needed
2. **Colocate data fetching** - Fetch data in the component that needs it
3. **Use React Query for client state** - Handle caching, refetching, optimistic updates
4. **Implement loading states** - Use Suspense and loading.tsx files
5. **Type everything** - Use TypeScript for all components and hooks
6. **Optimize images** - Use next/image for automatic optimization
7. **Minimize client JavaScript** - Keep interactive code small
