# [Feature Name] — Design

> Mostly static after brainstorming. Update only when a design decision changes.
> Record all changes in the Decisions Log.

## Technical Approach

[One paragraph: overall strategy and why.]

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `src/path/to/new.ts` | Create | [What it does] |
| `src/path/to/existing.ts` | Modify | [What changes] |

## Data Flow

```
Input → Validator → Service → Repository → DB
                       ↓
                 Event Bus → Subscriber
```

## Key Interfaces

```typescript
interface ExampleService {
  doThing(input: Input): Promise<Output>;
}
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | [logic] | [approach] |
| Integration | [flow] | [approach] |

## Decisions Log

| Date | Decision | Reason |
|------|----------|--------|
| [date] | [what was decided] | [why it beat alternatives] |
