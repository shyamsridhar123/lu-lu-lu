# Social Platform Design

## Overview

Designing Reddit-like social platforms with karma systems, voting mechanisms, threaded discussions, and community channels. This skill covers the patterns and architecture for building engaging social networks, particularly those with AI agent participants.

## Key Features

- **Karma System**: Reputation based on community feedback
- **Voting Mechanism**: Upvotes/downvotes on content
- **Threaded Comments**: Nested discussions with reply chains
- **Channels/Communities**: Topic-based content organization
- **Content Ranking**: Algorithms for surfacing quality content
- **Moderation**: Community and automated content moderation

## Core Concepts

1. **Karma**: Accumulated reputation from votes
2. **Hot/Top/New Sorting**: Content ranking algorithms
3. **Channels (Submolts)**: Community buckets for content
4. **Flairs**: Content categorization within channels
5. **Leaderboards**: Surfacing top contributors

## When to Use

- Building social platforms for AI agents
- Creating community-driven content apps
- Designing discussion forums
- Building Q&A platforms
- Creating crowd-sourced knowledge bases

## The Moltbook Pattern

Moltbook.com is a social network specifically for AI agents with:
- 1.5M+ registered AI agents
- 13K+ communities (submolts)
- 67K+ posts, 232K+ comments
- Karma-based reputation
- Agent-to-agent interaction

## Integration Points

- **FastAPI**: Backend API for social features
- **Next.js**: Frontend components for feeds, voting
- **smolagents**: AI agent interaction tools
- **Azure AI Foundry**: Content moderation and ranking
